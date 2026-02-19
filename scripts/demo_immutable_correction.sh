#!/bin/bash
# Demonstrate immutable correction: plaid_tx_013 had wrong amount, corrected via supersedes
# Proves: no UPDATE/DELETE, append-only versioning

set -e
BASE="${BASE_URL:-http://localhost:3000}"
# For DB query you need psql; this script shows the concept
# Run: psql $DATABASE_URL -c "SELECT id, provider_tx_id, amount, version, supersedes_transaction_id FROM transactions WHERE provider_tx_id = 'plaid_tx_013' ORDER BY version"

echo "=== Immutable correction (plaid_tx_013) ==="
echo "v1: amount -100 (incorrect) | v2: amount -10 (corrected, supersedes v1)"
echo ""
echo "Query to run:"
echo "  psql \$DATABASE_URL -c \"SELECT id, provider_tx_id, amount, version, supersedes_transaction_id FROM transactions WHERE provider_tx_id = 'plaid_tx_013' ORDER BY version\""
echo ""
echo "current_transactions view returns only v2 (latest)."
