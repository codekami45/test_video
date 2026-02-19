-- ============================================================================
-- FinTech Demo: Deterministic Finance + Agentic AI Schema
-- NDA-safe sanitized prototype for hiring verification
-- ============================================================================
-- All tables support multi-tenancy via tenant_id.
-- Transactions are immutable (no UPDATE/DELETE); corrections via supersedes.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Core tenant and user tables
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id TEXT NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, auth_user_id)
);

CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    provider TEXT NOT NULL,
    provider_account_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, provider, provider_account_id)
);

-- System categories have tenant_id NULL; tenant-specific categories have tenant_id set
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS categories_tenant_name_key
    ON categories (COALESCE(tenant_id::text, 'global'), name);

-- ----------------------------------------------------------------------------
-- Transactions: immutable, append-only, versioned
-- No UPDATE or DELETE; corrections via supersedes_transaction_id
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    account_id UUID NOT NULL REFERENCES accounts(id),
    provider_tx_id TEXT NOT NULL,
    amount NUMERIC(20, 4) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    description TEXT,
    occurred_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'posted')),
    version INT NOT NULL DEFAULT 1,
    supersedes_transaction_id UUID REFERENCES transactions(id),
    category_id UUID REFERENCES categories(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_hash TEXT,
    UNIQUE(tenant_id, provider_tx_id, version)
);

-- Trigger to compute row_hash on insert (deterministic fields for tamper detection)
CREATE OR REPLACE FUNCTION compute_transaction_row_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.row_hash := encode(
        sha256(
            (NEW.tenant_id::text || '|' ||
             NEW.provider_tx_id || '|' ||
             NEW.amount::text || '|' ||
             NEW.currency || '|' ||
             NEW.occurred_at::text || '|' ||
             NEW.status || '|' ||
             COALESCE(NEW.version::text, '1') || '|' ||
             COALESCE(NEW.supersedes_transaction_id::text, '') || '|' ||
             COALESCE(NEW.description, '')
            )::bytea
        ), 'hex'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_compute_transaction_row_hash
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE PROCEDURE compute_transaction_row_hash();

-- ----------------------------------------------------------------------------
-- Webhook events: idempotency via UNIQUE(tenant_id, source, event_id)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    source TEXT NOT NULL,
    event_id TEXT NOT NULL,
    payload_hash TEXT,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, source, event_id)
);

-- ----------------------------------------------------------------------------
-- Audit trail: all significant events
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    actor_type TEXT NOT NULL CHECK (actor_type IN ('user', 'ai', 'provider', 'system')),
    actor_id TEXT,
    event_type TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    diff JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- AI interactions and action proposals
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES app_users(id),
    question TEXT NOT NULL,
    response TEXT NOT NULL,
    citations JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_action_proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES app_users(id),
    ai_interaction_id UUID REFERENCES ai_interactions(id),
    action_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('proposed', 'confirmed', 'rejected', 'executed')) DEFAULT 'proposed',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmed_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- View: current_transactions
-- Returns only the latest version per logical transaction (tenant_id, provider_tx_id)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW current_transactions AS
SELECT DISTINCT ON (tenant_id, provider_tx_id)
    id, tenant_id, account_id, provider_tx_id, amount, currency, description,
    occurred_at, status, version, supersedes_transaction_id, category_id,
    created_at, row_hash
FROM transactions
ORDER BY tenant_id, provider_tx_id, version DESC, created_at DESC;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_transactions_tenant_account ON transactions(tenant_id, account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_occurred ON transactions(tenant_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_audit_events_tenant_created ON audit_events(tenant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_webhook_events_tenant_source ON webhook_events(tenant_id, source, event_id);
CREATE INDEX IF NOT EXISTS idx_ai_interactions_tenant_user ON ai_interactions(tenant_id, user_id);
CREATE INDEX IF NOT EXISTS idx_ai_action_proposals_status ON ai_action_proposals(tenant_id, status);

COMMIT;
