# FinTech Demo: Deterministic Finance + Agentic AI

> **NDA-safe sanitized prototype** for hiring verification (8–12 min Loom demo).

A minimal but credible prototype proving:

1. **Multi-tenancy** – `tenant_id` everywhere + Supabase/Postgres Row Level Security (RLS)
2. **Deterministic/immutable transactions** – no UPDATE/DELETE; corrections via append-only versioning
3. **Idempotent webhook ingestion** – Plaid-style: replay-safe, out-of-order tolerant, no duplicates
4. **Agentic AI (read-only)** – answers only from deterministic data with transaction ID citations
5. **AI proposes actions** – function calling; DB writes only after explicit user confirmation
6. **Full audit trail** – webhook ingest, AI read, proposal, confirmation, execution

No UI. Scripts/curl for demo.

---

## Repo Structure

```
fintech-demo/
├── db/
│   ├── schema.sql      # Tables, views, triggers, indexes
│   ├── policies.sql    # RLS policies for multi-tenancy
│   └── seed.sql        # 1 tenant, 1 user, 15–20 transactions
├── api/
│   ├── index.js        # Express server
│   ├── lib/db.js       # Tenant context, RLS helpers
│   └── routes/
│       ├── webhooks.js # POST /webhooks/transactions
│       ├── ai.js       # POST /ai/chat
│       └── actions.js  # POST /actions/confirm
├── scripts/            # Demo curl/PowerShell scripts
├── .env.example
├── package.json
└── README.md
```

---

## Setup

### Prerequisites

- Node.js 18+
- PostgreSQL 14+ (local or Supabase)
- OpenAI API key (for `/ai/chat`)

### 1. Database

**Local Postgres:**

```bash
createdb fintech_demo
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/fintech_demo
```

**Supabase:** Use your project's connection string (Settings → Database).

### 2. Migrate & Seed

```bash
# Apply schema, policies, seed
psql $DATABASE_URL -f db/schema.sql
psql $DATABASE_URL -f db/policies.sql
psql $DATABASE_URL -f db/seed.sql
```

Or use the script (Unix):

```bash
chmod +x scripts/seed_db.sh
./scripts/seed_db.sh
```

### 3. API

```bash
cp .env.example .env
# Edit .env: DATABASE_URL, OPENAI_API_KEY

npm install
npm start
```

API runs at `http://localhost:3000`.

---

## Demo Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/webhooks/transactions` | POST | Idempotent webhook ingestion |
| `/ai/chat` | POST | AI answers with citations, optional action proposal |
| `/actions/confirm` | POST | Execute proposal after user confirmation |
| `/health` | GET | Health check |

---

## Demo Steps (Exact Commands)

### 1. Immutable Correction

Seed includes `plaid_tx_013`: v1 had wrong amount -$100, v2 corrects to -$10.

```bash
psql $DATABASE_URL -c "SELECT id, provider_tx_id, amount, version, supersedes_transaction_id FROM transactions WHERE provider_tx_id = 'plaid_tx_013' ORDER BY version"
```

Shows two rows; `current_transactions` view returns only v2.

### 2. Webhook Idempotency (Replay)

```bash
# Unix
./scripts/send_webhook_twice.sh
```

```powershell
# Windows
.\scripts\send_webhook_twice.ps1
```

First call: `{"status":"ok","ingested":1}`. Second call (same `event_id`): `{"status":"duplicate_ignored"}`.

### 3. AI Answer with Citations + Server Validation

```bash
./scripts/ask_ai_starbucks_yesterday.sh
```

```powershell
.\scripts\ask_ai_starbucks_yesterday.ps1
```

Returns `response` + `citations` (transaction UUIDs). Server verifies each cited `transaction_id` exists.

### 4. AI Propose Action + Confirm + Audited Execution

```bash
./scripts/propose_and_confirm_recategorization.sh
```

```powershell
.\scripts\propose_and_confirm_recategorization.ps1
```

- Step 1: AI proposes recategorizing a Starbucks tx to Coffee (function calling).
- Step 2: User confirms → API creates new transaction version with category (append-only), marks proposal `executed`, writes audit.

---

## Patterns Proven

| Pattern | Implementation |
|---------|----------------|
| **Multi-tenancy** | `tenant_id` on all tables; RLS via `get_current_tenant_id()` (JWT or `app.current_tenant_id`) |
| **Immutable transactions** | `version`, `supersedes_transaction_id`; `current_transactions` view for latest |
| **Idempotent webhooks** | `webhook_events(tenant_id, source, event_id)` UNIQUE; duplicate → 200 "duplicate ignored" |
| **AI read-only** | Fetches from `current_transactions`; cites tx IDs; server validates citations |
| **Propose → Confirm** | AI uses `propose_recategorize` tool; `/actions/confirm` writes only after confirmation |
| **Audit trail** | `audit_events` for webhook, ingest, AI query, proposal, execution |

---

## Dev Mode / RLS

For local demo without JWT:

- API sets `app.current_tenant_id` per request from body/header.
- Policies use `get_current_tenant_id()` which reads that variable.
- In Supabase: JWT claim `tenant_id` is used instead.

---

## Seed Data Summary

- **Tenant:** Acme FinTech Demo  
- **User:** demo@acme.com  
- **Account:** Plaid `acc_plaid_001`  
- **Transactions:** 15+ including:
  - 3× Starbucks yesterday ($5.45, $6.80, $4.25)
  - `plaid_tx_012`: pending → posted (two versions)
  - `plaid_tx_013`: wrong amount corrected (v1 -$100, v2 -$10)
- **Categories:** Coffee, Food & Dining, Shopping, etc.

---

**NDA-safe sanitized prototype** – no proprietary logic, synthetic data only.
