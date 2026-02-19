#!/bin/bash
# Full flow: AI proposes recategorization -> user confirms -> audited execution
# Proves: AI proposes via function calling, DB write only after confirmation

set -e
BASE="${BASE_URL:-http://localhost:3000}"
TENANT="a1b2c3d4-0000-4000-8000-000000000001"
USER="u1111111-0000-4000-8000-000000000001"

# Step 1: Ask AI to propose recategorizing a Starbucks tx to Coffee
echo "=== Step 1: Ask AI to propose recategorizing a Starbucks transaction to Coffee ==="
RESP=$(curl -s -X POST "$BASE/ai/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'"$TENANT"'",
    "user_id": "'"$USER"'",
    "question": "Please propose recategorizing one of my Starbucks transactions from yesterday to the Coffee category. Which transaction would you suggest and why?"
  }')

echo "$RESP" | jq .

PROPOSAL_ID=$(echo "$RESP" | jq -r '.action_proposal.proposal_id // empty')
if [ -z "$PROPOSAL_ID" ] || [ "$PROPOSAL_ID" = "null" ]; then
  echo ""
  echo "No action_proposal in response (AI may not have proposed)."
  echo "For demo: use a known proposal_id from ai_action_proposals table,"
  echo "or re-run with OPENAI_API_KEY set - AI may propose via function calling."
  echo ""
  echo "To manually test confirm:"
  echo "  curl -X POST $BASE/actions/confirm -H 'Content-Type: application/json' \\"
  echo "    -d '{\"proposal_id\":\"<UUID>\",\"user_id\":\"$USER\",\"tenant_id\":\"$TENANT\"}'"
  exit 0
fi

echo ""
echo "Proposal ID: $PROPOSAL_ID"
echo ""

# Step 2: User confirms
echo "=== Step 2: User confirms proposal ==="
curl -s -X POST "$BASE/actions/confirm" \
  -H "Content-Type: application/json" \
  -d '{
    "proposal_id": "'"$PROPOSAL_ID"'",
    "user_id": "'"$USER"'",
    "tenant_id": "'"$TENANT"'"
  }' | jq .

echo ""
echo "Expected: {\"success\":true,\"action_type\":\"recategorize\"}"
echo "Execution is append-only: new transaction version with category_id, no UPDATE."
