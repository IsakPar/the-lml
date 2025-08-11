import type { FastifyInstance } from 'fastify';
import { RedisSeatLockAdapter, seatKey } from '../../../../../services/inventory/infrastructure/redis/adapter.js';
import { getDatabase } from '@thankful/database';
import { createClient as createRedisClient } from 'redis';
import { metrics } from '../../../../../packages/metrics/src/index.js';
import { problem } from '../../middleware/problem.js';
import { createRateLimitMiddleware } from '@thankful/ratelimit';
import { broadcast } from '../../utils/sse.js';
import { createIdemStore } from '../../../../../packages/idempotency/src/store.js';
import { canonicalHash } from '../../../../../packages/idempotency/src/index.js';
import { trace } from '@opentelemetry/api';

type HoldRequest = {
  performance_id: string;
  seats: string[];
  ttl_seconds?: number;
  sales_channel_id?: string;
};

type ExtendHoldRequest = {
  performance_id: string;
  seat_id: string;
  additional_seconds: number;
  hold_token?: string; // version:owner
};

export async function registerInventoryRoutes(app: FastifyInstance) {
  // Dependencies for demo wiring
  const redisUrl = String(process.env.REDIS_URL || 'redis://localhost:6379');
  const adapter = new RedisSeatLockAdapter(redisUrl);
  await adapter.connect();
  await adapter.loadScripts();
  // Idempotency store (use in-memory in tests for determinism)
  let idemStore: ReturnType<typeof createIdemStore>;
  if (process.env.NODE_ENV === 'test' || process.env.VITEST) {
    const memory = new Map<string, string>();
    const memClient = {
      get: async (k: string) => memory.get(k) ?? null,
      set: async (k: string, v: string, _mode: 'EX', ttlSec: number, flag?: 'NX' | 'XX') => {
        if (flag === 'NX' && memory.has(k)) return null;
        if (flag === 'XX' && !memory.has(k)) return null;
        memory.set(k, v);
        setTimeout(() => memory.delete(k), ttlSec * 1000).unref?.();
        return 'OK' as const;
      }
    } as const;
    idemStore = createIdemStore(memClient as any);
  } else {
    const redisNative = createRedisClient({ url: String(process.env.REDIS_URL || 'redis://localhost:6379') });
    await redisNative.connect();
    const idemClient = {
      get: (key: string) => redisNative.get(key),
      set: async (key: string, value: string, _mode: 'EX', ttlSec: number, flag?: 'NX' | 'XX') => {
        const opts: any = { EX: ttlSec };
        if (flag === 'NX') opts.NX = true;
        if (flag === 'XX') opts.XX = true;
        const res = await redisNative.set(key, value, opts);
        return res === 'OK' ? 'OK' : null;
      }
    };
    idemStore = createIdemStore(idemClient as any);
  }

  async function getCurrentToken(key: string): Promise<{ version: number; owner: string } | null> {
    try {
      const client = createRedisClient({ url: String(process.env.REDIS_URL || 'redis://localhost:6379') });
      await client.connect();
      const val = await client.get(key);
      await client.quit();
      if (val && val.includes(':')) {
        const idx = val.indexOf(':');
        const vStr = val.slice(0, idx);
        const owner = val.slice(idx + 1);
        const version = Number(vStr);
        if (Number.isFinite(version) && owner) return { version, owner };
      }
    } catch {}
    return null;
  }

  // POST /v1/holds
  const rlMutating = createRateLimitMiddleware({ limit: 10, windowSeconds: 60 });
  app.post('/v1/holds', { preHandler: rlMutating as any }, async (req: any, reply) => {
    const tracer = trace.getTracer('api');
    return await tracer.startActiveSpan('holds.acquire', async (span) => {
    // Require inventory scope
    const guard = (app as any).requireScopes?.(['inventory.holds:write']);
    if (guard) {
      const resp = await guard(req, reply);
      if (resp) return resp;
    }
    const db = getDatabase();
    await db.withTenant(String(req.ctx.orgId || ''), async () => {});
    const idemKey = req.headers['idempotency-key'];
    if (typeof idemKey !== 'string' || idemKey.length < 8) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_idempotency_key', 'Idempotency-Key required', 'urn:thankful:idem:missing', req.ctx?.traceId));
    }
    if (!req.ctx.orgId) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    }

    const body = req.body as HoldRequest;
    if (!body || !Array.isArray(body.seats) || !body.performance_id) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'performance_id and seats[] required', 'urn:thankful:inventory:invalid_hold_request', req.ctx?.traceId));
    }

    // Idempotency begin
    const tenant = req.ctx.orgId || 'dev-tenant';
    const contentType = String(req.headers['content-type'] || 'application/json');
    const bodyHash = canonicalHash({ method: 'POST', path: '/v1/holds', contentType, body });
    const storeKey = `idem:v1:holds:${tenant}:${bodyHash}`;
    const begin = await idemStore.begin(storeKey, req.ctx.requestId, 120);
    metrics.idem_begin_total.inc();
    if (begin.state === 'in-progress' && begin.ownerRequestId !== req.ctx.requestId) {
      reply.header('Idempotency-Status', 'in-progress');
      metrics.idem_inprogress_202_total.inc();
      return reply.code(202).send({ state: 'in-progress' });
    }
    if (begin.state === 'committed') {
      reply.header('Idempotency-Status', 'cached');
       metrics.idem_hit_cached_total.inc();
      // If we stored full response body, replay it
      if (begin.responseBody) {
        try {
          return reply.code(begin.status).send(JSON.parse(begin.responseBody));
        } catch {
          return reply.code(begin.status).send({ cached: true });
        }
      }
      return reply.code(begin.status).send({ cached: true });
    }

    const ttlMs = Math.max(1, Math.min(3600, body.ttl_seconds ?? 600)) * 1000;
    const keys = body.seats.map((s) => seatKey(tenant, body.performance_id, s));

    const owner = req.ctx.requestId;
    const version = Date.now();

    const result = await adapter.acquireAllOrNone(keys, owner, version, ttlMs);
    if ('conflictKeys' in result) {
      const conflictSeatIds = result.conflictKeys.map((k: string) => k.split(':').pop() || k);
      metrics.seat_lock_acquire_conflict_total.inc();
      return reply.code(409).type('application/problem+json').send({
        ...problem(409, 'conflict', 'some seats already held', 'urn:thankful:inventory:hold_conflict', req.ctx?.traceId),
        conflicts: conflictSeatIds,
      });
    }

    const expiresAt = new Date(Date.now() + ttlMs).toISOString();
    const holdId = `hold_${owner}`;
    const holdToken = `${version}:${owner}`; // fencing token
    const payload = { hold_id: holdId, hold_token: holdToken, expires_at: expiresAt, seats: body.seats.map((s) => ({ seat_id: s, status: 'held' })), trace_id: req.ctx?.traceId };
    // Broadcast SSE event with enriched payload
    for (const s of body.seats) broadcast('seat.locked', { performance_id: body.performance_id, seat_id: s, expires_at: expiresAt, sales_channel_id: body.sales_channel_id });
    // Idempotency commit (cache successful 201)
    const headersHash = 'h0';
    const respHash = canonicalHash({ method: 'POST', path: '/v1/holds', contentType: 'application/json', body: payload });
    await idemStore.commit(storeKey, { status: 201, headersHash, bodyHash: respHash, responseBody: JSON.stringify(payload) }, 24 * 3600);
    metrics.idem_commit_total.inc();
    metrics.seat_lock_acquire_ok_total.inc();
      span.setAttribute('tenantId', String(req.ctx.orgId));
      span.setAttribute('performanceId', body.performance_id);
      span.setAttribute('seats.count', body.seats.length);
      span.end();
      reply.header('Idempotency-Status', 'new');
      reply.code(201).send(payload);
    });
  });

  // PATCH /v1/holds (extend single seat hold for MVP)
  app.patch('/v1/holds', { preHandler: rlMutating as any }, async (req: any, reply) => {
    const tracer = trace.getTracer('api');
    return await tracer.startActiveSpan('holds.extend', async (span) => {
    const guard = (app as any).requireScopes?.(['inventory.holds:write']);
    if (guard) {
      const resp = await guard(req, reply);
      if (resp) return resp;
    }
    const body = req.body as ExtendHoldRequest;
    if (!body?.performance_id || !body?.seat_id || !body?.additional_seconds) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'performance_id, seat_id, additional_seconds required', 'urn:thankful:inventory:invalid_extend_request', req.ctx?.traceId));
    }
    if (!req.ctx.orgId) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    }

    // Idempotency for PATCH
    const idemKey = req.headers['idempotency-key'];
    if (typeof idemKey !== 'string' || idemKey.length < 8) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_idempotency_key', 'Idempotency-Key required', 'urn:thankful:idem:missing', req.ctx?.traceId));
    }
    const tenantForIdem = req.ctx.orgId || 'dev-tenant';
    const contentType = String(req.headers['content-type'] || 'application/json');
    const bodyHash = canonicalHash({ method: 'PATCH', path: '/v1/holds', contentType, body });
    const storeKey = `idem:v1:holds:extend:${tenantForIdem}:${bodyHash}`;
    const begin = await idemStore.begin(storeKey, req.ctx.requestId, 120);
    if (begin.state === 'in-progress' && begin.ownerRequestId !== req.ctx.requestId) {
      reply.header('Idempotency-Status', 'in-progress');
      return reply.code(202).send({ state: 'in-progress' });
    }
    if (begin.state === 'committed') {
      reply.header('Idempotency-Status', 'cached');
      if (begin.responseBody) {
        try { return reply.code(begin.status).send(JSON.parse(begin.responseBody)); } catch {}
      }
      return reply.code(begin.status).send({ cached: true });
    }
    const tenant = req.ctx.orgId || 'dev-tenant';
    const key = seatKey(tenant, body.performance_id, body.seat_id);

    // Determine version/owner for fencing
    let owner = req.ctx.requestId as string;
    let version = Date.now();
    if (body.hold_token && typeof body.hold_token === 'string' && body.hold_token.includes(':')) {
      const [vStr, oStr] = body.hold_token.split(':');
      const vNum = Number(vStr);
      if (Number.isFinite(vNum) && oStr) { version = vNum; owner = oStr; }
    } else {
      const tok = await getCurrentToken(key);
      if (tok) { version = tok.version; owner = tok.owner; }
    }
    const ttlMs = Math.max(1, Math.min(3600, body.additional_seconds)) * 1000;
    // Require concurrency token via If-Match or hold_token
    const ifMatch = req.headers['if-match'] as string | undefined;
    const token = body.hold_token || ifMatch || '';
    if (!token || !token.includes(':')) {
      return reply.code(412).type('application/problem+json').send(problem(412, 'precondition_required', 'hold_token or If-Match required', 'urn:thankful:inventory:precondition', req.ctx?.traceId));
    }
    const [vStr, oStr] = token.split(':');
    const vNum = Number(vStr);
    if (Number.isFinite(vNum) && oStr) { version = vNum; owner = oStr; }
    const db = getDatabase();
    await db.withTenant(String(req.ctx.orgId || ''), async () => {});
    const res = await adapter.extendIfOwner(key, owner, version, ttlMs);
    if (res === 'OK') metrics.seat_lock_extend_ok_total.inc();
    const response = res === 'OK' ? { extended: true, seat_id: body.seat_id, trace_id: req.ctx?.traceId } : { extended: false, result: res, trace_id: req.ctx?.traceId };
    const headersHash = 'h0';
    const respHash = canonicalHash({ method: 'PATCH', path: '/v1/holds', contentType: 'application/json', body: response });
    await idemStore.commit(storeKey, { status: 200, headersHash, bodyHash: respHash, responseBody: JSON.stringify(response) }, 6 * 3600);
      span.setAttribute('tenantId', String(req.ctx.orgId));
      span.setAttribute('performanceId', body.performance_id);
      span.setAttribute('seatId', body.seat_id);
      span.end();
      metrics.idem_commit_total.inc();
      return reply.code(200).send(response);
    });
  });

  // DELETE /v1/holds/:hold_id (demo: release single seat provided via query)
  app.delete('/v1/holds/:holdId', { preHandler: rlMutating as any }, async (req: any, reply) => {
    const tracer = trace.getTracer('api');
    return await tracer.startActiveSpan('holds.release', async (span) => {
    const guard = (app as any).requireScopes?.(['inventory.holds:write']);
    if (guard) {
      const resp = await guard(req, reply);
      if (resp) return resp;
    }
    const seatId = String(req.query?.seat_id || '');
    const perfId = String(req.query?.performance_id || '');
    const holdToken = (req.headers['if-match'] as string | undefined) || (req.query?.hold_token ? String(req.query.hold_token) : '');
    if (!seatId || !perfId) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'seat_id and performance_id required', 'urn:thankful:inventory:invalid_release_request', req.ctx?.traceId));
    if (!req.ctx.orgId) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    }

    // Idempotency for DELETE
    const idemKey = req.headers['idempotency-key'];
    if (typeof idemKey !== 'string' || idemKey.length < 8) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_idempotency_key', 'Idempotency-Key required', 'urn:thankful:idem:missing', req.ctx?.traceId));
    }
    const tenantForIdem = req.ctx.orgId || 'dev-tenant';
    const contentType = 'application/json';
    const idemBody = { seat_id: seatId, performance_id: perfId, hold_id: String(req.params.holdId) };
    const bodyHash = canonicalHash({ method: 'DELETE', path: `/v1/holds/${req.params.holdId}`, contentType, body: idemBody });
    const storeKey = `idem:v1:holds:release:${tenantForIdem}:${bodyHash}`;
    const begin = await idemStore.begin(storeKey, req.ctx.requestId, 120);
    if (begin.state === 'in-progress' && begin.ownerRequestId !== req.ctx.requestId) {
      reply.header('Idempotency-Status', 'in-progress');
      return reply.code(202).send({ state: 'in-progress' });
    }
    if (begin.state === 'committed') {
      reply.header('Idempotency-Status', 'cached');
      return reply.code(begin.status).send();
    }
    const tenant = req.ctx.orgId || 'dev-tenant';
    const key = seatKey(tenant, perfId, seatId);
    let owner = req.ctx.requestId as string;
    let version = Date.now();
    if (holdToken && holdToken.includes(':')) {
      const [vStr, oStr] = holdToken.split(':');
      const vNum = Number(vStr);
      if (Number.isFinite(vNum) && oStr) { version = vNum; owner = oStr; }
    } else {
      const tok = await getCurrentToken(key);
      if (tok) { version = tok.version; owner = tok.owner; }
    }
    if (!holdToken || !holdToken.includes(':')) {
      return reply.code(412).type('application/problem+json').send(problem(412, 'precondition_required', 'hold_token or If-Match required', 'urn:thankful:inventory:precondition', req.ctx?.traceId));
    }
    const db = getDatabase();
    await db.withTenant(String(req.ctx.orgId || ''), async () => {});
    const res = await adapter.releaseIfOwner(key, owner, version);
    if (res !== 'OK') {
      const payload = { released: false, result: res, trace_id: req.ctx?.traceId };
      const headersHash = 'h0';
      const respHash = canonicalHash({ method: 'DELETE', path: `/v1/holds/${req.params.holdId}`, contentType: 'application/json', body: payload });
      await idemStore.commit(storeKey, { status: 200, headersHash, bodyHash: respHash, responseBody: JSON.stringify(payload) }, 6 * 3600);
      metrics.idem_commit_total.inc();
      return reply.code(200).send(payload);
    }
    // Broadcast SSE event with enriched payload
    broadcast('seat.released', { performance_id: perfId, seat_id: seatId, sales_channel_id: req.query?.sales_channel_id, released_at: new Date().toISOString() });
    await idemStore.commit(storeKey, { status: 204, headersHash: 'h0', bodyHash: 'b0', responseBody: '' }, 6 * 3600);
      span.setAttribute('tenantId', String(req.ctx.orgId));
      span.setAttribute('performanceId', perfId);
      span.setAttribute('seatId', seatId);
      span.end();
      metrics.idem_commit_total.inc();
      metrics.seat_lock_release_ok_total.inc();
      return reply.code(204).send();
    });
  });
}


