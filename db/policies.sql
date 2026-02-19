-- ============================================================================
-- FinTech Demo: Row Level Security (RLS) Policies
-- Multi-tenancy: all access restricted by tenant_id from JWT or dev context
-- ============================================================================
-- In Supabase: JWT claim "tenant_id" is set by auth.
-- For local dev: use set_tenant_for_session(tenant_id) before queries.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Helper: get current tenant from JWT or session (dev mode)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
DECLARE
    claims JSONB;
    tid UUID;
BEGIN
    -- Try JWT first (Supabase sets request.jwt.claims)
    BEGIN
        claims := current_setting('request.jwt.claims', true)::jsonb;
        IF claims IS NOT NULL AND claims ? 'tenant_id' THEN
            tid := (claims->>'tenant_id')::uuid;
            IF tid IS NOT NULL THEN
                RETURN tid;
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- fall through to dev mode
    END;

    -- Dev mode: use session variable set by API layer
    tid := current_setting('app.current_tenant_id', true)::uuid;
    RETURN tid;
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Enable RLS on all tenant-scoped tables
-- ----------------------------------------------------------------------------
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_action_proposals ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- Drop existing policies for re-runnable migrations
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS tenants_select ON tenants;
DROP POLICY IF EXISTS app_users_policy ON app_users;
DROP POLICY IF EXISTS app_users_all ON app_users;
DROP POLICY IF EXISTS accounts_policy ON accounts;
DROP POLICY IF EXISTS accounts_all ON accounts;
DROP POLICY IF EXISTS categories_select ON categories;
DROP POLICY IF EXISTS transactions_policy ON transactions;
DROP POLICY IF EXISTS transactions_all ON transactions;
DROP POLICY IF EXISTS webhook_events_policy ON webhook_events;
DROP POLICY IF EXISTS webhook_events_all ON webhook_events;
DROP POLICY IF EXISTS audit_events_policy ON audit_events;
DROP POLICY IF EXISTS audit_events_all ON audit_events;
DROP POLICY IF EXISTS ai_interactions_policy ON ai_interactions;
DROP POLICY IF EXISTS ai_interactions_all ON ai_interactions;
DROP POLICY IF EXISTS ai_action_proposals_policy ON ai_action_proposals;
DROP POLICY IF EXISTS ai_action_proposals_all ON ai_action_proposals;

-- ----------------------------------------------------------------------------
-- TENANTS: users can only read their own tenant
-- ----------------------------------------------------------------------------
CREATE POLICY tenants_select ON tenants FOR SELECT
    USING (id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- APP_USERS: tenant-scoped (SELECT, INSERT, UPDATE with same tenant)
-- ----------------------------------------------------------------------------
CREATE POLICY app_users_policy ON app_users FOR ALL
    USING (tenant_id = get_current_tenant_id())
    WITH CHECK (tenant_id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- ACCOUNTS: tenant-scoped
-- ----------------------------------------------------------------------------
CREATE POLICY accounts_policy ON accounts FOR ALL
    USING (tenant_id = get_current_tenant_id())
    WITH CHECK (tenant_id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- CATEGORIES: system (tenant_id NULL) visible to all; tenant-specific scoped
-- ----------------------------------------------------------------------------
CREATE POLICY categories_select ON categories
    FOR SELECT USING (
        tenant_id IS NULL
        OR tenant_id = get_current_tenant_id()
    );

-- ----------------------------------------------------------------------------
-- TRANSACTIONS: tenant-scoped
-- ----------------------------------------------------------------------------
CREATE POLICY transactions_policy ON transactions FOR ALL
    USING (tenant_id = get_current_tenant_id())
    WITH CHECK (tenant_id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- WEBHOOK_EVENTS: tenant-scoped
-- ----------------------------------------------------------------------------
CREATE POLICY webhook_events_policy ON webhook_events FOR ALL
    USING (tenant_id = get_current_tenant_id())
    WITH CHECK (tenant_id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- AUDIT_EVENTS: tenant-scoped
-- ----------------------------------------------------------------------------
CREATE POLICY audit_events_policy ON audit_events FOR ALL
    USING (tenant_id = get_current_tenant_id())
    WITH CHECK (tenant_id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- AI_INTERACTIONS: tenant-scoped
-- ----------------------------------------------------------------------------
CREATE POLICY ai_interactions_policy ON ai_interactions FOR ALL
    USING (tenant_id = get_current_tenant_id())
    WITH CHECK (tenant_id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- AI_ACTION_PROPOSALS: tenant-scoped
-- ----------------------------------------------------------------------------
CREATE POLICY ai_action_proposals_policy ON ai_action_proposals FOR ALL
    USING (tenant_id = get_current_tenant_id())
    WITH CHECK (tenant_id = get_current_tenant_id());

-- ----------------------------------------------------------------------------
-- Service role bypass (Supabase service_role key bypasses RLS by default)
-- For API server: we use a single DB user and set app.current_tenant_id
-- per request, so RLS still applies when we set it.
-- ----------------------------------------------------------------------------

COMMIT;
