-- ============================================================================
-- FinTech Demo: Seed Data
-- 1 tenant, 1 user, 1 account, 15-20 transactions, categories
-- Includes: Starbucks "yesterday", pending->posted, corrected amount
-- ============================================================================

BEGIN;

-- Fixed UUIDs for deterministic demo
-- Tenant
INSERT INTO tenants (id, name) VALUES
    ('a1b2c3d4-0000-4000-8000-000000000001', 'Acme FinTech Demo')
ON CONFLICT (id) DO NOTHING;

-- Categories (system-wide: tenant_id NULL)
INSERT INTO categories (id, tenant_id, name) VALUES
    ('c1111111-0000-4000-8000-000000000001', NULL, 'Coffee'),
    ('c1111111-0000-4000-8000-000000000002', NULL, 'Food & Dining'),
    ('c1111111-0000-4000-8000-000000000003', NULL, 'Shopping'),
    ('c1111111-0000-4000-8000-000000000004', NULL, 'Transportation'),
    ('c1111111-0000-4000-8000-000000000005', NULL, 'Utilities'),
    ('c1111111-0000-4000-8000-000000000006', NULL, 'Uncategorized')
ON CONFLICT (id) DO NOTHING;

-- App user
INSERT INTO app_users (id, auth_user_id, tenant_id, email) VALUES
    ('u1111111-0000-4000-8000-000000000001', 'auth-user-1', 'a1b2c3d4-0000-4000-8000-000000000001', 'demo@acme.com')
ON CONFLICT (id) DO NOTHING;

-- Account
INSERT INTO accounts (id, tenant_id, provider, provider_account_id, status) VALUES
    ('acc11111-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'plaid', 'acc_plaid_001', 'active')
ON CONFLICT (id) DO NOTHING;

-- Transactions
-- Yesterday = 2025-02-18 for demo purposes (adjust if needed)
-- Using provider_tx_id as unique key per logical transaction

-- Starbucks transactions "yesterday" (several)
INSERT INTO transactions (id, tenant_id, account_id, provider_tx_id, amount, currency, description, occurred_at, status, version) VALUES
    ('tx-0001-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_001', -5.45, 'USD', 'STARBUCKS #12345', '2025-02-18 08:32:00-00', 'posted', 1),
    ('tx-0002-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_002', -6.80, 'USD', 'STARBUCKS #12345', '2025-02-18 14:15:00-00', 'posted', 1),
    ('tx-0003-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_003', -4.25, 'USD', 'STARBUCKS RESERVE', '2025-02-18 16:22:00-00', 'posted', 1);

-- Other transactions
INSERT INTO transactions (id, tenant_id, account_id, provider_tx_id, amount, currency, description, occurred_at, status, version, category_id) VALUES
    ('tx-0004-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_004', -12.99, 'USD', 'UBER EATS', '2025-02-18 19:00:00-00', 'posted', 1, 'c1111111-0000-4000-8000-000000000002'),
    ('tx-0005-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_005', -89.50, 'USD', 'AMAZON', '2025-02-17 10:00:00-00', 'posted', 1, 'c1111111-0000-4000-8000-000000000003'),
    ('tx-0006-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_006', -45.20, 'USD', 'SHELL GAS STATION', '2025-02-17 17:30:00-00', 'posted', 1, 'c1111111-0000-4000-8000-000000000004'),
    ('tx-0007-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_007', -2.50, 'USD', 'LINK NYC SUBWAY', '2025-02-18 07:45:00-00', 'posted', 1, 'c1111111-0000-4000-8000-000000000004'),
    ('tx-0008-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_008', 3500.00, 'USD', 'PAYROLL DEPOSIT', '2025-02-15 09:00:00-00', 'posted', 1, NULL),
    ('tx-0009-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_009', -128.00, 'USD', 'CONED UTILITIES', '2025-02-14 00:00:00-00', 'posted', 1, 'c1111111-0000-4000-8000-000000000005'),
    ('tx-0010-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_010', -15.00, 'USD', 'NETFLIX', '2025-02-16 00:00:00-00', 'posted', 1, NULL),
    ('tx-0011-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_011', -23.40, 'USD', 'TRADER JOES', '2025-02-18 18:30:00-00', 'posted', 1, 'c1111111-0000-4000-8000-000000000002');

-- PENDING -> POSTED: plaid_tx_012 initially pending, then posted (two versions)
INSERT INTO transactions (id, tenant_id, account_id, provider_tx_id, amount, currency, description, occurred_at, status, version, supersedes_transaction_id) VALUES
    ('tx-0012-v1-0000-4000-8000-0000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_012', -18.90, 'USD', 'CHIPOTLE PENDING', '2025-02-18 12:30:00-00', 'pending', 1, NULL);

INSERT INTO transactions (id, tenant_id, account_id, provider_tx_id, amount, currency, description, occurred_at, status, version, supersedes_transaction_id) VALUES
    ('tx-0012-v2-0000-4000-8000-0000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_012', -18.90, 'USD', 'CHIPOTLE #4567', '2025-02-18 12:30:00-00', 'posted', 2, 'tx-0012-v1-0000-4000-8000-0000000001');

-- CORRECTED: plaid_tx_013 v1 had wrong amount -$100, v2 corrects to -$10.00
INSERT INTO transactions (id, tenant_id, account_id, provider_tx_id, amount, currency, description, occurred_at, status, version, supersedes_transaction_id) VALUES
    ('tx-0013-v1-0000-4000-8000-0000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_013', -100.00, 'USD', 'PHARMACY (INCORRECT AMOUNT)', '2025-02-13 11:00:00-00', 'posted', 1, NULL);

INSERT INTO transactions (id, tenant_id, account_id, provider_tx_id, amount, currency, description, occurred_at, status, version, supersedes_transaction_id) VALUES
    ('tx-0013-v2-0000-4000-8000-0000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_013', -10.00, 'USD', 'CVS PHARMACY #789', '2025-02-13 11:00:00-00', 'posted', 2, 'tx-0013-v1-0000-4000-8000-0000000001');

-- A few more for variety
INSERT INTO transactions (id, tenant_id, account_id, provider_tx_id, amount, currency, description, occurred_at, status, version) VALUES
    ('tx-0014-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_014', -7.99, 'USD', 'STARBUCKS #67890', '2025-02-17 09:00:00-00', 'posted', 1),
    ('tx-0015-0000-4000-8000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', 'acc11111-0000-4000-8000-000000000001', 'plaid_tx_015', -3.25, 'USD', 'STARBUCKS REFRESH', '2025-02-16 15:20:00-00', 'posted', 1);

COMMIT;
