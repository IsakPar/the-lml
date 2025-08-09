import type { FastifyPluginCallback } from 'fastify';
import { createIdemStore } from './store.js';
import { metrics } from '@thankful/metrics';
import { canonicalHash } from './index.js';

export type RedisClient = {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, mode: 'EX', ttlSec: number, flag?: 'NX' | 'XX'): Promise<'OK' | null>;
};

export const idempotencyMiddleware: FastifyPluginCallback<{ client: RedisClient; tenant: string; routeKey: string; ttlSec: number; pendingTtlSec?: number }>
  = (app, opts, done) => {
    const store = createIdemStore(opts.client);
    // eslint-disable-next-line no-console
    console.log(`idempotency: registered routeKey=${opts.routeKey}`);
    app.addHook('preHandler', async (req, reply) => {
      if (req.method === 'GET' || req.method === 'HEAD') return; // mutate only
      const keyHeader = req.headers['idempotency-key'];
      if (typeof keyHeader !== 'string' || keyHeader.length < 8) {
        reply.code(422).type('application/problem+json').send({ type: 'urn:lml:platform:invalid-idempotency-key', title: 'invalid_idempotency_key', status: 422 });
        return reply;
      }
      const tenantId = (req.headers['x-tenant-id'] as string) || opts.tenant;
      reply.header('Cache-Control', 'no-store');
      // Build stable hash: whitelist headers and omit volatile demo fields
      let bodyForHash: unknown = req.body ?? null;
      if (opts.routeKey.includes('/_internal/idem/demo') && bodyForHash && typeof bodyForHash === 'object') {
        const b: any = { ...(bodyForHash as any) };
        delete b.delayMs;
        delete b.forceError;
        bodyForHash = b;
      }
      const bodyHash = canonicalHash({ method: req.method, path: opts.routeKey, contentType: String(req.headers['content-type'] || ''), body: bodyForHash });
      const idemKey = `idem:v1:${tenantId}:${opts.routeKey}:${bodyHash}`;
      const currentReqId = String((req as any).id || Date.now());
      const begin = await store.begin(idemKey, currentReqId, opts.pendingTtlSec ?? 120);
      reply.header('Idempotency-Key', keyHeader);
      // eslint-disable-next-line no-console
      console.log(JSON.stringify({ event: 'idem.begin', tenantId, routeKey: opts.routeKey, keySuffix: bodyHash, state: begin.state }));
      if (begin.state === 'in-progress') {
        metrics.idem_inprogress_202_total.inc();
        reply.header('Idempotency-Status', 'in-progress');
        reply.code(202).header('Retry-After', '1').send({ state: 'in-progress' });
        return reply;
      }
      if (begin.state === 'committed') {
        metrics.idem_hit_cached_total.inc();
        reply.header('Idempotency-Status', 'cached');
        reply.code(begin.status).send({ cached: true });
        return reply;
      }
      // else: allow handler to run; capture onSend to commit
      reply.header('Idempotency-Status', 'new');
      app.addHook('onSend', async (req2: any, reply2: any, payload: any) => {
        try {
          const status = reply2.statusCode;
          if (status >= 500) return payload;
          const headersHash = 'h0'; // simple stub; configurable include
          const commitHash = canonicalHash({ method: req2.method, path: opts.routeKey, contentType: String(reply2.getHeader('content-type') || ''), body: payload });
          await store.commit(idemKey, { status, headersHash, bodyHash: commitHash }, opts.ttlSec);
          // eslint-disable-next-line no-console
          console.log(JSON.stringify({ event: 'idem.commit', tenantId, routeKey: opts.routeKey, keySuffix: bodyHash, status }));
          return payload;
        } catch {
          return payload;
        }
      });
    });
    done();
  };
