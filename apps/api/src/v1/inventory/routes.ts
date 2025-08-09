import type { FastifyInstance } from 'fastify';
import { RedisSeatLockAdapter, seatKey } from '../../../../../services/inventory/infrastructure/redis/adapter.js';
import { createClient as createRedisClient } from 'redis';
import { problem } from '../../middleware/problem.js';
import { rateLimit } from '../../middleware/rateLimit.js';

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
  app.post('/v1/holds', { preHandler: rateLimit(10, 60) }, async (req: any, reply) => {
    const idemKey = req.headers['idempotency-key'];
    if (typeof idemKey !== 'string' || idemKey.length < 8) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_idempotency_key', 'Idempotency-Key required', 'urn:thankful:idem:missing', req.ctx?.traceId));
    }

    const body = req.body as HoldRequest;
    if (!body || !Array.isArray(body.seats) || !body.performance_id) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'performance_id and seats[] required', 'urn:thankful:inventory:invalid_hold_request', req.ctx?.traceId));
    }

    const tenant = req.ctx.orgId || 'dev-tenant';
    const ttlMs = Math.max(1, Math.min(3600, body.ttl_seconds ?? 600)) * 1000;
    const keys = body.seats.map((s) => seatKey(tenant, body.performance_id, s));

    const owner = req.ctx.requestId;
    const version = Date.now();

    const result = await adapter.acquireAllOrNone(keys, owner, version, ttlMs);
    if ('conflictKeys' in result) {
      const conflictSeatIds = result.conflictKeys.map((k: string) => k.split(':').pop() || k);
      return reply.code(409).type('application/problem+json').send({
        ...problem(409, 'conflict', 'some seats already held', 'urn:thankful:inventory:hold_conflict', req.ctx?.traceId),
        conflicts: conflictSeatIds,
      });
    }

    const expiresAt = new Date(Date.now() + ttlMs).toISOString();
    const holdId = `hold_${owner}`;
    const holdToken = `${version}:${owner}`; // fencing token
    reply.code(201).send({ hold_id: holdId, hold_token: holdToken, expires_at: expiresAt, seats: body.seats.map((s) => ({ seat_id: s, status: 'held' })), trace_id: req.ctx?.traceId });
  });

  // PATCH /v1/holds (extend single seat hold for MVP)
  app.patch('/v1/holds', { preHandler: rateLimit(10, 60) }, async (req: any, reply) => {
    const body = req.body as ExtendHoldRequest;
    if (!body?.performance_id || !body?.seat_id || !body?.additional_seconds) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'performance_id, seat_id, additional_seconds required', 'urn:thankful:inventory:invalid_extend_request', req.ctx?.traceId));
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
    const res = await adapter.extendIfOwner(key, owner, version, ttlMs);
    if (res !== 'OK') return reply.code(200).send({ extended: false, result: res, trace_id: req.ctx?.traceId });
    return reply.code(200).send({ extended: true, seat_id: body.seat_id, trace_id: req.ctx?.traceId });
  });

  // DELETE /v1/holds/:hold_id (demo: release single seat provided via query)
  app.delete('/v1/holds/:holdId', { preHandler: rateLimit(10, 60) }, async (req: any, reply) => {
    const seatId = String(req.query?.seat_id || '');
    const perfId = String(req.query?.performance_id || '');
    const holdToken = req.query?.hold_token ? String(req.query.hold_token) : '';
    if (!seatId || !perfId) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'seat_id and performance_id required', 'urn:thankful:inventory:invalid_release_request', req.ctx?.traceId));
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
    const res = await adapter.releaseIfOwner(key, owner, version);
    if (res !== 'OK') return reply.code(200).send({ released: false, result: res, trace_id: req.ctx?.traceId });
    return reply.code(204).send();
  });
}


