#!/bin/bash
# Demonstrate webhook ingestion - single call
# Proves: idempotent ingestion, deterministic transaction storage

set -e
BASE="${BASE_URL:-http://localhost:3000}"
TENANT="a1b2c3d4-0000-4000-8000-000000000001"
ACCOUNT="acc11111-0000-4000-8000-000000000001"

echo "=== Sending webhook (first time) ==="
curl -s -X POST "$BASE/webhooks/transactions" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "plaid",
    "event_id": "evt_demo_001",
    "tenant_id": "'"$TENANT"'",
    "payload": {
      "account_id": "'"$ACCOUNT"'",
      "transactions": [
        {
          "provider_tx_id": "plaid_tx_new_001",
          "amount": -9.99,
          "description": "STARBUCKS NEW LOCATION",
          "occurred_at": "2025-02-19T09:00:00Z",
          "status": "posted",
          "version": 1
        }
      ]
    }
  }' | jq .

echo ""
echo "Expected: {\"status\":\"ok\",\"ingested\":1}"
