#!/bin/bash
# Run schema + policies + seed
# Requires: PostgreSQL running, DATABASE_URL or default postgresql://postgres:postgres@localhost:5432/fintech_demo

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/fintech_demo}"

echo "=== Creating database (if needed) ==="
psql "$DB_URL" -c "SELECT 1" 2>/dev/null || {
  echo "Create database first: createdb fintech_demo"
  echo "Then run: psql \$DATABASE_URL -f db/schema.sql"
  echo "          psql \$DATABASE_URL -f db/policies.sql"
  echo "          psql \$DATABASE_URL -f db/seed.sql"
  exit 1
}

echo "=== Running schema ==="
psql "$DB_URL" -f "$PROJECT_ROOT/db/schema.sql"

echo "=== Running policies ==="
psql "$DB_URL" -f "$PROJECT_ROOT/db/policies.sql"

echo "=== Running seed ==="
psql "$DB_URL" -f "$PROJECT_ROOT/db/seed.sql"

echo ""
echo "Done. Start API: npm start"
