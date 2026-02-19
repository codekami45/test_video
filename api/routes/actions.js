/**
 * POST /actions/confirm
 * Execute an AI-proposed action only after user confirmation.
 * - Validates proposal belongs to tenant/user and is "proposed"
 * - Does NOT update transaction rows; records changes via new transaction version
 *   or category assignment event (append-only)
 * - Marks proposal executed, audit trail
 */

const express = require('express');
const router = express.Router();
const { withTenant } = require('../lib/db');

router.post('/confirm', async (req, res) => {
  try {
    const { proposal_id, user_id, tenant_id } = req.body;

    if (!proposal_id || !user_id || !tenant_id) {
      return res.status(400).json({
        error: 'Missing required fields: proposal_id, user_id, tenant_id',
      });
    }

    const pool = req.pool;

    const result = await withTenant(pool, tenant_id, async (client) => {
      // Fetch proposal (must belong to tenant; RLS enforces via set tenant context)
      const prop = await client.query(
        `SELECT p.id, p.tenant_id, p.user_id, p.action_type, p.payload, p.status
         FROM ai_action_proposals p
         WHERE p.id = $1`,
        [proposal_id]
      );

      if (prop.rows.length === 0) {
        return { error: 'Proposal not found' };
      }

      const p = prop.rows[0];
      if (p.user_id !== user_id) {
        return { error: 'Proposal does not belong to user' };
      }
      if (p.status !== 'proposed') {
        return { error: `Proposal already ${p.status}` };
      }

      const tenantId = p.tenant_id;
      if (tenant_id && tenant_id !== tenantId) {
        return { error: 'Tenant mismatch' };
      }

      if (p.action_type === 'recategorize') {
        const { transaction_id, category_name } = p.payload;

        const cat = await client.query(
          `SELECT id FROM categories WHERE name = $1 AND (tenant_id IS NULL OR tenant_id = $2) LIMIT 1`,
          [category_name, tenantId]
        );
        if (cat.rows.length === 0) {
          return { error: `Category "${category_name}" not found` };
        }
        const categoryId = cat.rows[0].id;

        const tx = await client.query(
          `SELECT id, provider_tx_id, amount, currency, description, occurred_at, status, version
           FROM current_transactions
           WHERE id = $1 AND tenant_id = $2`,
          [transaction_id, tenantId]
        );
        if (tx.rows.length === 0) {
          return { error: 'Transaction not found' };
        }

        const current = tx.rows[0];
        const nextVersion = (current.version || 1) + 1;

        // Append-only: insert new transaction version with category_id, superseding previous
        await client.query(
          `INSERT INTO transactions (
            tenant_id, account_id, provider_tx_id, amount, currency, description,
            occurred_at, status, version, supersedes_transaction_id, category_id
          ) VALUES ($1, (SELECT account_id FROM transactions WHERE id = $2), $3, $4, $5, $6, $7, $8, $9, $2, $10)`,
          [
            tenantId,
            transaction_id,
            current.provider_tx_id,
            current.amount,
            current.currency,
            current.description,
            current.occurred_at,
            current.status,
            nextVersion,
            categoryId,
          ]
        );

        await client.query(
          `INSERT INTO audit_events (tenant_id, actor_type, actor_id, event_type, entity_type, entity_id, diff)
           VALUES ($1, 'user', $2, 'recategorize_executed', 'transactions', $3, $4)`,
          [tenantId, user_id, transaction_id, JSON.stringify({ category_id: categoryId, category_name, new_version: nextVersion })]
        );
      }

      // Mark proposal executed
      await client.query(
        `UPDATE ai_action_proposals
         SET status = 'executed', confirmed_at = now(), executed_at = now()
         WHERE id = $1`,
        [proposal_id]
      );

      await client.query(
        `INSERT INTO audit_events (tenant_id, actor_type, actor_id, event_type, entity_type, entity_id, diff)
         VALUES ($1, 'user', $2, 'proposal_executed', 'ai_action_proposals', $3, $4)`,
        [tenantId, user_id, proposal_id, JSON.stringify({ action_type: p.action_type })]
      );

      return { success: true, action_type: p.action_type };
    });

    if (result.error) {
      return res.status(400).json({ error: result.error });
    }

    res.json(result);
  } catch (err) {
    console.error('Actions confirm error:', err);
    res.status(500).json({ error: 'Action confirmation failed', message: err.message });
  }
});

module.exports = router;
