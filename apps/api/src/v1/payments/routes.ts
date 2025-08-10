import type { FastifyInstance } from 'fastify';
import { getDatabase } from '@thankful/database';
import { problem } from '../../middleware/problem.js';
import { createRateLimitMiddleware } from '@thankful/ratelimit';
import { createClient as createRedisClient } from 'redis';
import { createIdemStore } from '../../../../../packages/idempotency/src/store.js';
import { canonicalHash } from '../../../../../packages/idempotency/src/index.js';
import crypto from 'node:crypto';
import { notifyOrderConfirmed } from '../../../../../packages/notifications/src/index.js';

type CreateIntentRequest = {
  order_id: string;
  amount_minor: number;
  currency?: string;
};

export async function registerPaymentsRoutes(app: FastifyInstance) {
  const rl = createRateLimitMiddleware({ limit: 10, windowSeconds: 60 });

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
  const idemStore = createIdemStore(idemClient as any);

  // POST /v1/payments/intents (mock/dev provider): create DB record and return client_secret
  app.post('/v1/payments/intents', { preHandler: rl as any }, async (req: any, reply) => {
    const guard = (app as any).requireScopes?.(['payments.write']);
    if (guard) { const resp = await guard(req, reply); if (resp) return resp as any; }
    if (!req.ctx?.orgId) return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    const idemKey = req.headers['idempotency-key'];
    if (typeof idemKey !== 'string' || idemKey.length < 8) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_idempotency_key', 'Idempotency-Key required', 'urn:thankful:idem:missing', req.ctx?.traceId));
    const body = (req.body || {}) as CreateIntentRequest;
    if (!body.order_id || !Number.isFinite(body.amount_minor)) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'order_id and amount_minor required', 'urn:thankful:payments:invalid_intent', req.ctx?.traceId));
    const currency = (body.currency || process.env.DEFAULT_CURRENCY || 'USD').toString();

    // Idempotency begin
    const tenant = req.ctx.orgId as string;
    const contentType = String(req.headers['content-type'] || 'application/json');
    const bodyHash = canonicalHash({ method: 'POST', path: '/v1/payments/intents', contentType, body });
    const storeKey = `idem:v1:payments:intents:${tenant}:${bodyHash}`;
    const begin = await idemStore.begin(storeKey, req.ctx.requestId, 180);
    if (begin.state === 'in-progress' && begin.ownerRequestId !== req.ctx.requestId) { reply.header('Idempotency-Status', 'in-progress'); return reply.code(202).send({ state: 'in-progress' }); }
    if (begin.state === 'committed') { reply.header('Idempotency-Status', 'cached'); if (begin.responseBody) { try { return reply.code(begin.status).send(JSON.parse(begin.responseBody)); } catch {} } return reply.code(begin.status).send({ cached: true }); }

    const db = getDatabase();
    let piId = '';
    let clientSecret = '';
    await db.withTenant(tenant, async (client) => {
      const res = await client.query<{ id: string }>(
        'INSERT INTO payments.payment_intents(order_id, status, amount_minor, currency, provider) VALUES ($1,$2,$3,$4,$5) RETURNING id',
        [body.order_id, 'requires_payment_method', body.amount_minor, currency, 'mock']
      );
      piId = res.rows[0].id;
    });
    clientSecret = `pi_${piId}_secret_${crypto.randomBytes(8).toString('hex')}`;

    const payload = { payment_intent_id: piId, client_secret: clientSecret, amount_minor: body.amount_minor, currency, status: 'requires_payment_method', trace_id: req.ctx?.traceId };
    const headersHash = 'h0';
    const respHash = canonicalHash({ method: 'POST', path: '/v1/payments/intents', contentType: 'application/json', body: payload });
    await idemStore.commit(storeKey, { status: 201, headersHash, bodyHash: respHash, responseBody: JSON.stringify(payload) }, 24 * 3600);
    reply.header('Idempotency-Status', 'new');
    return reply.code(201).send(payload);
  });

  // POST /v1/payments/webhook/stripe (dev-friendly)
  app.post('/v1/payments/webhook/stripe', async (req: any, reply) => {
    // In dev, we accept parsed JSON; in prod, recommend raw-body verification
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    const sig = (req.headers['stripe-signature'] as string | undefined) || '';
    const event = req.body || {};
    // Optional naive verification for dev: HMAC of JSON string
    if (secret && typeof event === 'object') {
      try {
        const raw = JSON.stringify(event);
        const v1 = crypto.createHmac('sha256', secret).update(raw).digest('hex');
        const provided = sig.split('v1=')[1]?.split(',')[0];
        if (!provided || provided !== v1) {
          return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_signature', 'signature verification failed', 'urn:thankful:payments:invalid_sig', (req as any).ctx?.traceId));
        }
      } catch {
        return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_payload', 'unable to parse payload', 'urn:thankful:payments:invalid_payload', (req as any).ctx?.traceId));
      }
    }

    const type = event?.type as string;
    const data = event?.data?.object || {};
    const piId = data?.id as string | undefined;
    const tenant = (req.headers['x-org-id'] as string) || (req as any).ctx?.orgId || '';
    // Webhook is unauthenticated; allow tenant via header or default test tenant during tests
    if (!tenant && process.env.NODE_ENV !== 'test') return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', (req as any).ctx?.traceId));
    if (!piId) return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_request', 'payment_intent id missing', 'urn:thankful:payments:invalid_event', (req as any).ctx?.traceId));

    const db = getDatabase();
    await db.withTenant(tenant, async (client) => {
      if (type === 'payment_intent.succeeded') {
        await client.query('UPDATE payments.payment_intents SET status=$1 WHERE id=$2', ['succeeded', piId]);
        // Link to order and mark paid if present
        const res = await client.query<{ order_id: string }>('SELECT order_id FROM payments.payment_intents WHERE id=$1', [piId]);
        const ordId = res.rows[0]?.order_id;
        if (ordId) await client.query('UPDATE orders.orders SET status=$1 WHERE id=$2', ['paid', ordId]);
        // Fire-and-forget notification
        if (ordId) { try { await notifyOrderConfirmed({ orderId: ordId, tenantId: tenant }); } catch {} }
      } else if (type === 'payment_intent.payment_failed' || type === 'payment_intent.canceled') {
        await client.query('UPDATE payments.payment_intents SET status=$1 WHERE id=$2', ['failed', piId]);
      }
    });
    return reply.code(200).send({ received: true });
  });
}


