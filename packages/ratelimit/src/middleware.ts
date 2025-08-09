import type { FastifyReply, FastifyRequest } from 'fastify';
import type { RateLimiterPort } from './index.js';

export function rateLimit(limiter: RateLimiterPort, cfg: { route: string; tenant: string; limit: number; windowSec: number; subject: 'ip' | 'userOrIp' }) {
  return async function (req: FastifyRequest, reply: FastifyReply) {
    const subject = cfg.subject === 'ip' ? req.ip : ((req as any).user?.id ?? req.ip);
    const res = await limiter.allow(cfg.route, cfg.tenant, String(subject), cfg.limit, cfg.windowSec);
    if (!res.allowed) {
      if (res.retryAfterSeconds) reply.header('Retry-After', String(res.retryAfterSeconds));
      return reply.code(429).send({
        type: 'https://problems/rate-limit',
        title: 'Too many requests',
        status: 429,
        details: { code: 'RATE_LIMIT' }
      });
    }
  };
}



