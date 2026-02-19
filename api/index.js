/**
 * FinTech Demo API
 * NDA-safe sanitized prototype: deterministic finance + agentic AI
 *
 * Endpoints:
 * - POST /webhooks/transactions  (idempotent, Plaid-style)
 * - POST /ai/chat                (read-only AI, citations, proposals)
 * - POST /actions/confirm        (execute proposal after user confirmation)
 */

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const webhooksRouter = require('./routes/webhooks');
const aiRouter = require('./routes/ai');
const actionsRouter = require('./routes/actions');

const app = express();
const PORT = process.env.PORT || 3000;

// DB pool (connects as app user; RLS applies when we set tenant context)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/fintech_demo',
});

app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Attach pool to req for routes
app.use((req, res, next) => {
  req.pool = pool;
  next();
});

// Routes
app.use('/webhooks', webhooksRouter);
app.use('/ai', aiRouter);
app.use('/actions', actionsRouter);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Start server
app.listen(PORT, () => {
  console.log(`FinTech Demo API running on http://localhost:${PORT}`);
});
