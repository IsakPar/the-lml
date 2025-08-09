import { createIdemStore } from './store.js';
import { canonicalHash } from './index.js';

// Stub metrics to avoid import issues
const metrics = {
    idem_inprogress_202_total: { inc: () => {} },
    idem_hit_cached_total: { inc: () => {} }
};
export const idempotencyMiddleware = (app, opts, done) => {
    const store = createIdemStore(opts.client);
    // eslint-disable-next-line no-console
    console.log(`idempotency: registered routeKey=${opts.routeKey}`);
    app.addHook('preHandler', async (req, reply) => {
        // eslint-disable-next-line no-console
        console.log(`IDEM MIDDLEWARE CALLED: ${req.method} ${req.url}`);
        if (req.method === 'GET' || req.method === 'HEAD')
            return; // mutate only
        const keyHeader = req.headers['idempotency-key'];
        if (typeof keyHeader !== 'string' || keyHeader.length < 8) {
            reply.code(422).type('application/problem+json').send({ type: 'urn:lml:platform:invalid-idempotency-key', title: 'invalid_idempotency_key', status: 422 });
            return reply;
        }
        const tenantId = (req.headers['x-tenant-id'] || opts.tenant);
        reply.header('Cache-Control', 'no-store');
        // Build stable hash: omit volatile demo fields
        let bodyForHash = req.body ?? null;
        if (opts.routeKey.includes('/_internal/idem/demo') && bodyForHash && typeof bodyForHash === 'object') {
            const b = { ...bodyForHash };
            delete b.delayMs;
            delete b.forceError;
            bodyForHash = b;
        }
        const bodyHash = canonicalHash({ method: req.method, path: opts.routeKey, contentType: String(req.headers['content-type'] || ''), body: bodyForHash });
        const idemKey = `idem:v1:${tenantId}:${opts.routeKey}:${bodyHash}`;
        const currentReqId = String(req.id || Date.now());
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
        app.addHook('onSend', async (req2, reply2, payload) => {
            try {
                const status = reply2.statusCode;
                if (status >= 500)
                    return payload;
                const headersHash = 'h0'; // simple stub; configurable include
                const commitHash = canonicalHash({ method: req2.method, path: opts.routeKey, contentType: String(reply2.getHeader('content-type') || ''), body: payload });
                await store.commit(idemKey, { status, headersHash, bodyHash: commitHash }, opts.ttlSec);
                // eslint-disable-next-line no-console
                console.log(JSON.stringify({ event: 'idem.commit', tenantId, routeKey: opts.routeKey, keySuffix: bodyHash, status }));
                return payload;
            }
            catch {
                return payload;
            }
        });
    });
    done();
};