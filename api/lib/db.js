/**
 * DB helpers: set tenant context for RLS (dev mode)
 * In Supabase, tenant comes from JWT; here we set via session variable
 */
async function setTenantContext(client, tenantId) {
  await client.query("SET LOCAL app.current_tenant_id = $1", [tenantId]);
}

async function withTenant(pool, tenantId, fn) {
  const client = await pool.connect();
  try {
    await setTenantContext(client, tenantId);
    return await fn(client);
  } finally {
    client.release();
  }
}

function hashPayload(payload) {
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}

module.exports = { setTenantContext, withTenant, hashPayload };
