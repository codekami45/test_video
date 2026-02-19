#!/bin/bash
# Demonstrate webhook IDEMPOTENCY - send same event twice
# Proves: replay-safe, duplicate ignored, returns 200

set -e
BASE="${BASE_URL:-http://localhost:3000}"
TENANT="a1b2c3d4-0000-4000-8000-000000000001"
ACCOUNT="acc11111-0000-4000-8000-000000000001"

echo "=== Sending webhook FIRST time (event_id: evt_idempotent_demo) ==="
curl -s -X POST "$BASE/webhooks/transactions" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "plaid",
    "event_id": "evt_idempotent_demo",
    "tenant_id": "'"$TENANT"'",
    "payload": {
      "account_id": "'"$ACCOUNT"'",
      "transactions": [
        {
          "provider_tx_id": "plaid_tx_idem_001",
          "amount": -3.50,
          "description": "DUPLICATE TEST TX",
          "occurred_at": "2025-02-19T10:00:00Z",
          "status": "posted",
          "version": 1
        }
      ]
    }
  }' | jq .

echo ""
echo "=== Sending SAME webhook SECOND time (idempotency test) ==="
curl -s -X POST "$BASE/webhooks/transactions" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "plaid",
    "event_id": "evt_idempotent_demo",
    "tenant_id": "'"$TENANT"'",
    "payload": {
      "account_id": "'"$ACCOUNT"'",
      "transactions": [
        {
          "provider_tx_id": "plaid_tx_idem_001",
          "amount": -3.50,
          "description": "DUPLICATE TEST TX",
          "occurred_at": "2025-02-19T10:00:00Z",
          "status": "posted",
          "version": 1
        }
      ]
    }
  }' | jq .

echo ""
echo "Expected second response: {\"status\":\"duplicate_ignored\",\"message\":\"Event already processed\"}"
