import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import stringify from 'fast-json-stable-stringify';
import type { IdempotencyRecord } from './index.js';

function canonicalBodyHash(req: FastifyRequest) {
  const method = req.method.toUpperCase();
  const path = req.routerPath ?? req.url;
  const contentType = (req.headers['content-type'] ?? '').toString();
  const body = (req.body ?? null) as unknown;
  const stable = stringify(body);
  let h = 0;
  const input = `${method}:${path}:${contentType}:${stable}`;
  for (let i = 0; i < input.length; i++) h = Math.imul(31, h) + input.charCodeAt(i) | 0; // eslint-disable-line no-bitwise
  return String(h >>> 0);
}

export async function withIdempotency(app: FastifyInstance, store: {
  get: (key: string) => Promise<IdempotencyRecord | null>;
  setPending: (key: string, rec: IdempotencyRecord, ttlSec: number) => Promise<boolean>;
  finalize: (key: string, updater: (prev: IdempotencyRecord) => IdempotencyRecord, ttlSec: number) => Promise<void>;
}) {
  app.addHook('preHandler', async (req, reply) => {
    if (req.method === 'GET') return;
    const idemKey = (req.headers['idempotency-key'] ?? '').toString().trim();
    if (!idemKey) return;
    const bodyHash = canonicalBodyHash(req);
    const storeKey = `lml:idem:${req.method}:${req.routerPath ?? req.url}:default:${idemKey}`;
    const existing = await store.get(storeKey);
    if (existing) {
      if (existing.bodyHash !== bodyHash) {
        return reply.code(409).send({
          type: 'https://problems/idempotency-body-mismatch',
          title: 'Idempotency key reused with different body',
          status: 409,
          details: { code: 'IDEMPOTENCY_KEY_REUSE_DIFFERENT_BODY' }
        });
      }
      if (existing.status === 'pending') {
        return reply.code(409).send({
          type: 'https://problems/idempotency-in-progress',
          title: 'Request with this idempotency key is still being processed',
          status: 409,
          details: { code: 'IDEMPOTENCY_IN_PROGRESS' }
        });
      }
      // status done -> let handler run or short-circuit via route-specific loader later
      // For now, fall-through so stub routes can simply return
      return;
    }
    const rec: IdempotencyRecord = {
      status: 'pending',
      bodyHash,
      contentType: (req.headers['content-type'] ?? '').toString(),
      method: req.method,
      path: req.routerPath ?? req.url,
      expiresAt: Math.floor(Date.now() / 1000) + 86400
    };
    await store.setPending(storeKey, rec, 86400);
  });

  app.addHook('onSend', async (req, _reply: FastifyReply, payload) => {
    if (req.method === 'GET') return;
    const idemKey = (req.headers['idempotency-key'] ?? '').toString().trim();
    if (!idemKey) return;
    const storeKey = `lml:idem:${req.method}:${req.routerPath ?? req.url}:default:${idemKey}`;
    await store.finalize(storeKey, (prev) => ({
      ...prev,
      status: 'done',
      httpStatus: (typeof _reply.statusCode === 'number' ? _reply.statusCode : 200) as number,
      resourceId: (() => { try { const o = typeof payload === 'string' ? JSON.parse(payload) : payload as any; return o?.id ?? o?.orderId; } catch { return undefined; } })()
    }), 86400);
  });
}



