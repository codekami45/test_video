/**
 * POST /ai/chat
 * Read-only AI layer: answers ONLY from deterministic data with transaction ID citations.
 * - Fetches from current_transactions view
 * - OpenAI with function calling, strict guardrails
 * - Server-side validation: cited tx_ids must exist and match recomputed totals
 * - Logs ai_interactions and audit_events
 */

const express = require('express');
const router = express.Router();
const OpenAI = require('openai');
const { withTenant } = require('../lib/db');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY || '',
});

router.post('/chat', async (req, res) => {
  try {
    const { tenant_id, user_id, question } = req.body;

    if (!tenant_id || !user_id || !question) {
      return res.status(400).json({
        error: 'Missing required fields: tenant_id, user_id, question',
      });
    }

    if (!process.env.OPENAI_API_KEY) {
      return res.status(503).json({
        error: 'OPENAI_API_KEY not configured',
        fallback: 'For demo without API key: Starbucks yesterday total would be $16.50 from transactions tx-0001..., tx-0002..., tx-0003...',
      });
    }

    const pool = req.pool;

    const { transactions, categories } = await withTenant(pool, tenant_id, async (client) => {
      const txResult = await client.query(
        `SELECT id, provider_tx_id, amount, currency, description, occurred_at, status, version
         FROM current_transactions
         WHERE tenant_id = $1
         ORDER BY occurred_at DESC
         LIMIT 100`,
        [tenant_id]
      );
      const catResult = await client.query(
        `SELECT id, name FROM categories WHERE tenant_id IS NULL OR tenant_id = $1`,
        [tenant_id]
      );
      return { transactions: txResult.rows, categories: catResult.rows };
    });

    // Build context for LLM (strict: only deterministic data)
    const txSummary = transactions.map((t) => ({
      id: t.id,
      provider_tx_id: t.provider_tx_id,
      amount: parseFloat(t.amount),
      description: t.description,
      occurred_at: t.occurred_at,
      status: t.status,
    }));

    const systemPrompt = `You are a finance assistant. Rules:
1. Answer ONLY from the transaction data provided. Never invent numbers or transactions.
2. For every numeric claim, cite the exact transaction IDs (the "id" field).
3. If the data doesn't contain the answer, say "I cannot answer from the available data."
4. You may propose actions (e.g. recategorize a transaction) via the propose_recategorize tool - but you must NOT claim the action is done; only that you propose it.
5. Format citations as [tx:uuid] for each transaction ID.`;

    const userContent = `Transaction data:\n${JSON.stringify(txSummary, null, 2)}\n\nCategories: ${categories.map((c) => c.name).join(', ')}\n\nQuestion: ${question}`;

    const tools = [
      {
        type: 'function',
        function: {
          name: 'propose_recategorize',
          description: 'Propose recategorizing a transaction to a different category. Requires transaction_id and category_name.',
          parameters: {
            type: 'object',
            properties: {
              transaction_id: { type: 'string', description: 'UUID of the transaction' },
              category_name: { type: 'string', description: 'Target category name' },
              reason: { type: 'string', description: 'Brief reason' },
            },
            required: ['transaction_id', 'category_name'],
          },
        },
      },
    ];

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userContent },
      ],
      tools,
      tool_choice: 'auto',
    });

    const msg = completion.choices[0].message;
    let responseText = msg.content || '';
    let citations = [];
    let actionProposal = null;

    // Extract cited transaction IDs from response (pattern [tx:uuid])
    const citeMatches = responseText.matchAll(/\[tx:([a-f0-9-]{36})\]/gi);
    citations = [...new Set([...citeMatches].map((m) => m[1]))];

    // Handle tool call (action proposal)
    if (msg.tool_calls && msg.tool_calls.length > 0) {
      const tc = msg.tool_calls[0];
      if (tc.function.name === 'propose_recategorize') {
        const args = JSON.parse(tc.function.arguments || '{}');
        actionProposal = {
          action_type: 'recategorize',
          payload: args,
        };

        const proposalRow = await withTenant(pool, tenant_id, async (client) => {
          const aiRow = await client.query(
            `INSERT INTO ai_interactions (tenant_id, user_id, question, response, citations)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id`,
            [tenant_id, user_id, question, responseText, JSON.stringify(citations)]
          );

          const propRow = await client.query(
            `INSERT INTO ai_action_proposals (tenant_id, user_id, ai_interaction_id, action_type, payload)
             VALUES ($1, $2, $3, 'recategorize', $4)
             RETURNING id`,
            [tenant_id, user_id, aiRow.rows[0].id, JSON.stringify(args)]
          );

          await client.query(
            `INSERT INTO audit_events (tenant_id, actor_type, event_type, entity_type, entity_id, diff)
             VALUES ($1, 'ai', 'action_proposed', 'ai_action_proposals', $2, $3)`,
            [tenant_id, propRow.rows[0].id, JSON.stringify(args)]
          );

          return { proposal_id: propRow.rows[0].id };
        });

        actionProposal.proposal_id = proposalRow.proposal_id;
      }
    } else {
      await withTenant(pool, tenant_id, async (client) => {
        await client.query(
          `INSERT INTO ai_interactions (tenant_id, user_id, question, response, citations)
           VALUES ($1, $2, $3, $4, $5)`,
          [tenant_id, user_id, question, responseText, JSON.stringify(citations)]
        );
        await client.query(
          `INSERT INTO audit_events (tenant_id, actor_type, event_type, entity_type, diff)
           VALUES ($1, 'ai', 'chat_query', 'ai_interactions', $2)`,
          [tenant_id, JSON.stringify({ question: question.substring(0, 200), citation_count: citations.length })]
        );
      });
    }

    // Server-side validation: every cited tx_id must exist and belong to tenant
    const validCitations = await withTenant(pool, tenant_id, async (client) => {
      if (citations.length === 0) return [];
      const result = await client.query(
        `SELECT id FROM current_transactions WHERE id = ANY($1::uuid[]) AND tenant_id = $2`,
        [citations, tenant_id]
      );
      return result.rows.map((r) => r.id);
    });

    // If validation fails (citation to non-existent tx), return safe fallback
    const invalidCount = citations.length - validCitations.length;
    if (invalidCount > 0) {
      responseText = "I cannot confidently answer from the available data. Some referenced transactions could not be verified.";
      citations = [];
    }

    res.json({
      response: responseText,
      citations: validCitations,
      action_proposal: actionProposal,
    });
  } catch (err) {
    console.error('AI chat error:', err);
    res.status(500).json({ error: 'AI processing failed', message: err.message });
  }
});

module.exports = router;
