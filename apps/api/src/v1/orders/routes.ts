import type { FastifyInstance } from 'fastify';
import { getDatabase } from '@thankful/database';
import { createRateLimitMiddleware } from '@thankful/ratelimit';
import { problem } from '../../middleware/problem.js';
import { createClient as createRedisClient } from 'redis';
import { createIdemStore } from '../../../../../packages/idempotency/src/store.js';
import { canonicalHash } from '../../../../../packages/idempotency/src/index.js';

type CreateOrderRequest = {
  currency?: string;
  total_minor?: number;
  lines?: Array<{ sku?: string; performance_id?: string; seat_id?: string; price_minor?: number }>; // minimal placeholder
};

export async function registerOrdersRoutes(app: FastifyInstance) {
  const rlMutating = createRateLimitMiddleware({ limit: 10, windowSeconds: 60 });

  // Idempotency store: in tests use in-memory; otherwise Redis
  let idemStore: ReturnType<typeof createIdemStore>;
  if (process.env.NODE_ENV === 'test') {
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

  // POST /v1/orders
  app.post('/v1/orders', { preHandler: rlMutating as any }, async (req: any, reply) => {
    const guard = (app as any).requireScopes?.(['orders.write']);
    if (guard) {
      const resp = await guard(req, reply);
      if (resp) return resp as any;
    }
    if (!req.ctx?.orgId) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    }
    const idemKey = req.headers['idempotency-key'];
    if (typeof idemKey !== 'string' || idemKey.length < 8) {
      return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_idempotency_key', 'Idempotency-Key required', 'urn:thankful:idem:missing', req.ctx?.traceId));
    }
    const body = (req.body || {}) as CreateOrderRequest;
    const currency = (body.currency || process.env.DEFAULT_CURRENCY || 'USD').toString();
    const totalMinor = Number.isFinite(body.total_minor) ? Number(body.total_minor) : 0;

    // Idempotency begin
    const tenant = req.ctx.orgId as string;
    const contentType = String(req.headers['content-type'] || 'application/json');
    const bodyHash = canonicalHash({ method: 'POST', path: '/v1/orders', contentType, body: body });
    const storeKey = `idem:v1:orders:create:${tenant}:${bodyHash}`;
    const begin = await idemStore.begin(storeKey, req.ctx.requestId, 180);
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

    // Insert order
    const db = getDatabase();
    let orderId: string = '';
    await db.withTenant(tenant, async (client) => {
      const res = await client.query<{ id: string }>(
        'INSERT INTO orders.orders(status, total_minor, currency) VALUES ($1, $2, $3) RETURNING id',
        ['pending', totalMinor, currency]
      );
      orderId = res.rows[0].id;
    });

    const payload = { order_id: orderId, status: 'pending', currency, total_minor: totalMinor, trace_id: req.ctx?.traceId };
    const headersHash = 'h0';
    const respHash = canonicalHash({ method: 'POST', path: '/v1/orders', contentType: 'application/json', body: payload });
    await idemStore.commit(storeKey, { status: 201, headersHash, bodyHash: respHash, responseBody: JSON.stringify(payload) }, 24 * 3600);
    reply.header('Idempotency-Status', 'new');
    return reply.code(201).send(payload);
  });

  // GET /v1/orders/:id
  app.get('/v1/orders/:id', async (req: any, reply) => {
    const guard = (app as any).requireScopes?.(['orders.read']);
    if (guard) {
      const resp = await guard(req, reply);
      if (resp) return resp as any;
    }
    const id = String(req.params.id || '');
    if (!id) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'id required', 'urn:thankful:orders:invalid_id', req.ctx?.traceId));
    const db = getDatabase();
    let row: any = null;
    await db.withTenant(String(req.ctx.orgId || ''), async (client) => {
      const res = await client.query<{ id: string; status: string; currency: string; total_minor: string }>('SELECT id, status, currency, total_minor FROM orders.orders WHERE id = $1', [id]);
      row = res.rows[0] || null;
    });
    if (!row) return reply.code(404).type('application/problem+json').send(problem(404, 'not_found', 'order not found', 'urn:thankful:orders:not_found', req.ctx?.traceId));
    return { order_id: row.id, status: row.status, currency: row.currency, total_minor: Number(row.total_minor), trace_id: req.ctx?.traceId };
  });
}


