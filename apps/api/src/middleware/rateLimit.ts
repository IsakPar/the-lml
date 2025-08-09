import type { FastifyReply, FastifyRequest } from 'fastify';

type Bucket = { remaining: number; resetAt: number; limit: number };
const store = new Map<string, Bucket>();

export function rateLimit(maxPerWindow: number, windowSeconds: number) {
  return async (req: FastifyRequest, reply: FastifyReply) => {
    const now = Date.now();
    const windowMs = windowSeconds * 1000;
    const id = (req.user?.userId || req.ctx.orgId || req.ip) + ':' + req.routerPath + ':' + req.method;
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


