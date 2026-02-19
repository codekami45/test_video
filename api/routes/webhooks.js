/**
 * POST /webhooks/transactions
 * Idempotent, Plaid-style webhook ingestion.
 * - Insert webhook_events first; duplicate event_id -> 200 "duplicate ignored"
 * - Ingest transactions deterministically (provider_tx_id unique per tenant)
 * - pending->posted: append new version superseding previous
 * - Full audit trail
 */

const express = require('express');
const router = express.Router();
const { withTenant, hashPayload } = require('../lib/db');

router.post('/transactions', async (req, res) => {
  try {
    const { source, event_id, tenant_id, payload } = req.body;

    if (!source || !event_id || !tenant_id || !payload) {
      return res.status(400).json({
        error: 'Missing required fields: source, event_id, tenant_id, payload',
      });
    }

    const pool = req.pool;
    const payloadHash = hashPayload(payload);

    const result = await withTenant(pool, tenant_id, async (client) => {
      // 1. Insert webhook_events (idempotency: UNIQUE tenant_id, source, event_id)
      let webhookInserted = false;
      try {
        await client.query(
          `INSERT INTO webhook_events (tenant_id, source, event_id, payload_hash)
           VALUES ($1, $2, $3, $4)`,
          [tenant_id, source, event_id, payloadHash]
        );
        webhookInserted = true;
      } catch (err) {
        if (err.code === '23505') {
          // Unique violation = duplicate event
          return { duplicate: true, ingested: 0 };
        }
        throw err;
      }

      // 2. Audit: webhook receipt
      await client.query(
        `INSERT INTO audit_events (tenant_id, actor_type, event_type, entity_type, diff)
         VALUES ($1, 'provider', 'webhook_received', 'webhook_events', $2)`,
        [tenant_id, JSON.stringify({ source, event_id, payload_hash: payloadHash })]
      );

      const transactions = Array.isArray(payload.transactions) ? payload.transactions : [];
      const accountId = payload.account_id;
      let ingested = 0;

      for (const tx of transactions) {
        const providerTxId = tx.provider_tx_id || tx.id;
        const amount = parseFloat(tx.amount);
        const status = tx.status || 'posted';
        const description = tx.description || tx.name || '';
        const occurredAt = tx.occurred_at || tx.date || new Date().toISOString();
        const version = tx.version || 1;
        const supersedesTxId = tx.supersedes_transaction_id || null;

        // Check if this exact (tenant_id, provider_tx_id, version) exists
        const existing = await client.query(
          `SELECT id FROM transactions WHERE tenant_id = $1 AND provider_tx_id = $2 AND version = $3`,
          [tenant_id, providerTxId, version]
        );

        if (existing.rows.length > 0) {
          continue; // Skip duplicate
        }

        await client.query(
          `INSERT INTO transactions (
            tenant_id, account_id, provider_tx_id, amount, currency, description,
            occurred_at, status, version, supersedes_transaction_id
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            tenant_id,
            accountId,
            providerTxId,
            amount,
            tx.currency || 'USD',
            description,
            occurredAt,
            status,
            version,
            supersedesTxId,
          ]
        );

        const txRow = await client.query(
          `SELECT id FROM transactions WHERE tenant_id = $1 AND provider_tx_id = $2 AND version = $3`,
          [tenant_id, providerTxId, version]
        );

        await client.query(
          `INSERT INTO audit_events (tenant_id, actor_type, event_type, entity_type, entity_id, diff)
           VALUES ($1, 'provider', 'transaction_ingested', 'transactions', $2, $3)`,
          [tenant_id, txRow.rows[0].id, JSON.stringify({ provider_tx_id: providerTxId, amount, status, version })]
        );
        ingested++;
      }

      return { duplicate: false, ingested };
    });

    if (result.duplicate) {
      return res.status(200).json({ status: 'duplicate_ignored', message: 'Event already processed' });
    }

    res.status(200).json({ status: 'ok', ingested: result.ingested });
  } catch (err) {
    console.error('Webhook error:', err);
    res.status(500).json({ error: 'Webhook processing failed', message: err.message });
  }
});

module.exports = router;
