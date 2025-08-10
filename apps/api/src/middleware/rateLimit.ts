import type { FastifyReply, FastifyRequest } from 'fastify';

type Bucket = { remaining: number; resetAt: number; limit: number };
const store = new Map<string, Bucket>();

export function rateLimit(maxPerWindow: number, windowSeconds: number) {
  return async (req: FastifyRequest, reply: FastifyReply) => {
    const now = Date.now();
    const windowMs = windowSeconds * 1000;
    const routeUrl = (req as any).routeOptions?.url || (req.url.split('?')[0]);
    const id = (req.user?.userId || req.ctx.orgId || req.ip) + ':' + routeUrl + ':' + req.method;
    let bucket = store.get(id);
    if (!bucket || now >= bucket.resetAt) {
      bucket = { remaining: maxPerWindow, resetAt: now + windowMs, limit: maxPerWindow };
      store.set(id, bucket);
    }
    if (bucket.remaining <= 0) {
      const resetSec = Math.ceil((bucket.resetAt - now) / 1000);
      reply
        .header('X-RateLimit-Limit', bucket.limit)
        .header('X-RateLimit-Remaining', 0)
        .header('X-RateLimit-Reset', resetSec)
        .header('Retry-After', resetSec)
        .code(429)
        .send({ type: 'urn:thankful:rate_limit:exceeded', title: 'rate_limit', status: 429, detail: `retry in ${resetSec}s`, trace_id: req.ctx?.traceId });
      return reply;
    }
    bucket.remaining -= 1;
    const resetSec = Math.ceil((bucket.resetAt - now) / 1000);
    reply
      .header('X-RateLimit-Limit', bucket.limit)
      .header('X-RateLimit-Remaining', Math.max(0, bucket.remaining))
      .header('X-RateLimit-Reset', resetSec);
  };
}

export function rateLimitByKey(maxPerWindow: number, windowSeconds: number, keyFn: (req: FastifyRequest) => string) {
  return async (req: FastifyRequest, reply: FastifyReply) => {
    const now = Date.now();
    const windowMs = windowSeconds * 1000;
    const key = keyFn(req);
    let bucket = store.get(key);
    if (!bucket || now >= bucket.resetAt) {
      bucket = { remaining: maxPerWindow, resetAt: now + windowMs, limit: maxPerWindow };
      store.set(key, bucket);
    }
    if (bucket.remaining <= 0) {
      const resetSec = Math.ceil((bucket.resetAt - now) / 1000);
      reply
        .header('X-RateLimit-Limit', bucket.limit)
        .header('X-RateLimit-Remaining', 0)
        .header('X-RateLimit-Reset', resetSec)
        .header('Retry-After', resetSec)
        .code(429)
        .send({ type: 'urn:thankful:rate_limit:exceeded', title: 'rate_limit', status: 429, detail: `retry in ${resetSec}s`, trace_id: (req as any).ctx?.traceId });
      return reply;
    }
    bucket.remaining -= 1;
    const resetSec = Math.ceil((bucket.resetAt - now) / 1000);
    reply
      .header('X-RateLimit-Limit', bucket.limit)
      .header('X-RateLimit-Remaining', Math.max(0, bucket.remaining))
      .header('X-RateLimit-Reset', resetSec);
  };
}


