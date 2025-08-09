import { Pool, PoolClient } from 'pg';
import { log } from '../../logging/src/index.js';

// Connection pool (read from DATABASE_URL)
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// withTenant runs fn(client) within a transaction where app.tenant_id is set for RLS
export async function withTenant<T>(tenantId: string, requestId: string, fn: (client: PoolClient) => Promise<T>): Promise<T> {
  if (!tenantId || tenantId.trim().length === 0) {
    log('db.tenant_missing', { request_id: requestId });
    throw new Error('TENANT_MISSING');
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`SET LOCAL app.tenant_id = $1`, [tenantId]);
    await client.query(`SET LOCAL statement_timeout = '5s'`);
    await client.query(`SET LOCAL idle_in_transaction_session_timeout = '5s'`);
    const result = await fn(client);
    await client.query('COMMIT');
    log('db.tx_committed', { tenant: tenantId, request_id: requestId });
    return result;
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch {}
    log('db.tx_rolled_back', { tenant: tenantId, request_id: requestId, error: (err as Error).message });
    throw err;
  } finally {
    client.release();
  }
}

// Repositories must accept a PoolClient provided by withTenant; no raw client exports here.

// API surface
// withTenant(tenantId, fn): begin transaction; SET LOCAL app.tenant_id = $tenantId; run fn(client); commit/rollback.
// getClient(): not exposed publicly; repositories receive a client from withTenant only.
// Enforcement: No DB call is allowed outside withTenant; all repos accept a client param and do not self-create connections.
// Failure modes: missing/empty tenant -> fail operation, log tenant_missing, return typed error.
// Telemetry: include tenant and request_id in spans/logs for each operation.
