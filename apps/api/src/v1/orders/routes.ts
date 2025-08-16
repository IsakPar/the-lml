import type { FastifyInstance } from 'fastify';
import { getDatabase } from '@thankful/database';
import { createRateLimitMiddleware } from '@thankful/ratelimit';
import { problem } from '../../middleware/problem.js';
import { createClient as createRedisClient } from 'redis';
import { createIdemStore } from '../../../../../packages/idempotency/src/store.js';
import { canonicalHash } from '../../../../../packages/idempotency/src/index.js';
import Stripe from 'stripe';

type CreateOrderRequest = {
  performance_id: string;
  seat_ids: string[];
  currency?: string;
  total_minor?: number;
  customer_email: string;
};

export async function registerOrdersRoutes(app: FastifyInstance) {
  const rlMutating = createRateLimitMiddleware({ limit: 10, windowSeconds: 60 });
  
  // Initialize Stripe
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {
    apiVersion: '2024-12-18.acacia',
  });

  // Idempotency store: in tests use in-memory; otherwise Redis
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
    const { performance_id, seat_ids, customer_email } = body;
    const currency = (body.currency || process.env.DEFAULT_CURRENCY || 'USD').toString();

    // Validation
    if (!performance_id || !seat_ids || !Array.isArray(seat_ids) || seat_ids.length === 0) {
      return reply.code(422).type('application/problem+json').send(
        problem(422, 'invalid_request', 'performance_id and seat_ids required', 'urn:thankful:orders:missing_fields', req.ctx?.traceId)
      );
    }

    // Email validation
    if (!customer_email || !customer_email.trim()) {
      return reply.code(422).type('application/problem+json').send(
        problem(422, 'invalid_request', 'customer_email is required', 'urn:thankful:orders:missing_email', req.ctx?.traceId)
      );
    }

    // TODO: Verify seats are held by this user (Redis check)
    // For now, we'll proceed assuming seats are properly held

    const db = getDatabase();
    const tenant = req.ctx.orgId as string;
    let orderId: string = '';
    let clientSecret: string = '';
    
    // Calculate total amount (moved outside callback for scope)
    const pricePerSeat = 2500; // £25.00 in pence  
    const totalMinor = seat_ids.length * pricePerSeat;
    
    try {
      await db.withTenant(tenant, async (client) => {
        // Start transaction
        await client.query('BEGIN');
        
        try {

          // Create order (using correct schema and column names)
          const orderResult = await client.query<{ id: string }>(
            'INSERT INTO orders.orders (status, total_minor, currency, customer_email) VALUES ($1, $2, $3, $4) RETURNING id',
            ['pending', totalMinor, currency, customer_email.trim()]
          );
          orderId = orderResult.rows[0].id;

          // Reserve seats in inventory.seat_state table (this tracks seat ownership per order)
          for (const seatId of seat_ids) {
            const updateResult = await client.query(
              `UPDATE inventory.seat_state SET state = 'reserved', order_id = $1, updated_at = NOW()
               WHERE seat_id = $2 AND state = 'available' AND performance_id = $3`,
              [orderId, seatId, performance_id]
            );
            
            if (updateResult.rowCount === 0) {
              throw new Error(`Seat ${seatId} is no longer available`);
            }
          }

          // Create Stripe PaymentIntent
          const paymentIntent = await stripe.paymentIntents.create({
            amount: totalMinor,
            currency: currency.toLowerCase(),
            metadata: {
              order_id: orderId,
              performance_id,
              seat_count: seat_ids.length.toString(),
              org_id: tenant,
              customer_email: customer_email.trim()
            },
            automatic_payment_methods: {
              enabled: true,
            },
          });

          clientSecret = paymentIntent.client_secret || '';

          // Update order with PaymentIntent ID
          await client.query(
            'UPDATE orders.orders SET payment_intent_id = $1, updated_at = NOW() WHERE id = $2',
            [paymentIntent.id, orderId]
          );

          await client.query('COMMIT');
          
        } catch (error) {
          await client.query('ROLLBACK');
          throw error;
        }
      });

      const payload = { 
        order_id: orderId, 
        client_secret: clientSecret,
        status: 'pending', 
        currency, 
        total_amount: totalMinor,  // Match iOS expectations
        performance_id,
        seat_count: seat_ids.length,
        trace_id: req.ctx?.traceId 
      };
      
      return reply.code(201).send(payload);
      
    } catch (error) {
      console.error('Order creation failed:', error);
      return reply.code(422).type('application/problem+json').send(
        problem(422, 'order_creation_failed', error instanceof Error ? error.message : 'Unknown error', 'urn:thankful:orders:creation_failed', req.ctx?.traceId)
      );
    }
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


