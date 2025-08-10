import { createClient } from 'redis';
import { buildKey } from './port.js';
export class RedisRateLimiter {
    url;
    client;
    ready = false;
    constructor(url) {
        this.url = url;
        this.client = createClient({ url });
    }
    async connect() {
        if (!this.ready) {
            await this.client.connect();
            this.ready = true;
        }
    }
    async allow(key, limit, windowSec) {
        const now = Math.floor(Date.now() / 1000);
        const windowKey = `rl:${key}`;
        const ttl = windowSec;
        const multi = this.client.multi();
        multi.incr(windowKey);
        // Use EXPIRE NX semantics via string flag to satisfy typings
        multi.expire(windowKey, ttl, 'NX');
        const [countRaw] = (await multi.exec());
        const count = Number(countRaw ?? 1);
        if (count > limit) {
            const ttlLeft = await this.client.ttl(windowKey);
            return { allowed: false, retryAfterSeconds: Math.max(1, ttlLeft) };
        }
        const ttlLeft = await this.client.ttl(windowKey);
        return { allowed: true, remaining: Math.max(0, limit - count), limit };
    }
}
export function createRateLimitMiddleware(opts) {
    const redis = new RedisRateLimiter(opts.redisUrl || process.env.RATE_LIMIT_REDIS_URL || process.env.REDIS_URL || 'redis://localhost:6379');
    let initPromise = null;
    async function ensure() {
        if (!initPromise)
            initPromise = redis.connect();
        return initPromise;
    }
    return async (req, reply) => {
        await ensure();
        const routeUrl = req.routeOptions?.url || req.url.split('?')[0];
        const tenant = req.ctx?.orgId || req.headers['x-org-id'] || 'anon';
        const subject = (opts.keyFn ? opts.keyFn(req) : (req.user?.userId || req.ip));
        const key = buildKey([tenant, routeUrl, req.method, subject]);
        const result = await redis.allow(key, opts.limit, opts.windowSeconds);
        const resetSec = result.retryAfterSeconds || 0;
        reply
            .header('X-RateLimit-Limit', opts.limit)
            .header('X-RateLimit-Remaining', Math.max(0, result.remaining ?? 0))
            .header('X-RateLimit-Reset', resetSec);
        if (!result.allowed) {
            reply.header('Retry-After', resetSec);
            return reply.code(429).type('application/problem+json').send({ type: 'urn:thankful:rate_limit:exceeded', title: 'rate_limit', status: 429, detail: `retry in ${resetSec}s`, trace_id: req.ctx?.traceId });
        }
    };
}
