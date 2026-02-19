#!/bin/bash
# Ask AI: "How much did I spend at Starbucks yesterday?"
# Proves: AI answers from deterministic data, cites transaction IDs, server validation

set -e
BASE="${BASE_URL:-http://localhost:3000}"
TENANT="a1b2c3d4-0000-4000-8000-000000000001"
USER="u1111111-0000-4000-8000-000000000001"

echo "=== Asking AI: Starbucks spend yesterday ==="
echo "Question: How much did I spend at Starbucks yesterday?"
echo ""

curl -s -X POST "$BASE/ai/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'"$TENANT"'",
    "user_id": "'"$USER"'",
    "question": "How much did I spend at Starbucks yesterday? Please cite each transaction ID."
  }' | jq .

echo ""
echo "Expected: response with citations array containing transaction UUIDs"
echo "Note: Requires OPENAI_API_KEY. If unset, returns 503 with demo fallback."
