import type { FastifyReply, FastifyRequest } from 'fastify';
import { createClient, type RedisClientType } from 'redis';
import { buildKey, type RateLimitDecision } from './port.js';

export type RateLimitOptions = Readonly<{
  limit: number;
  windowSeconds: number;
  redisUrl?: string;
  keyFn?: (req: FastifyRequest) => string;
}>;

export class RedisRateLimiter {
  private client: RedisClientType;
  private ready = false;
  constructor(private readonly url: string) {
    this.client = createClient({ url });
  }
  async connect(): Promise<void> {
    if (!this.ready) {
      await this.client.connect();
      this.ready = true;
    }
  }
  async allow(key: string, limit: number, windowSec: number): Promise<RateLimitDecision> {
    const now = Math.floor(Date.now() / 1000);
    const windowKey = `rl:${key}`;
    const ttl = windowSec;
    const multi = this.client.multi();
    multi.incr(windowKey);
    // Use EXPIRE NX semantics via string flag to satisfy typings
    multi.expire(windowKey, ttl, 'NX' as any);
    const [countRaw] = (await multi.exec()) as Array<number | unknown>;
    const count = Number(countRaw ?? 1);
    if (count > limit) {
      const ttlLeft = await this.client.ttl(windowKey);
      return { allowed: false, retryAfterSeconds: Math.max(1, ttlLeft) };
    }
    const ttlLeft = await this.client.ttl(windowKey);
    return { allowed: true, remaining: Math.max(0, limit - count), limit };
  }
}

export function createRateLimitMiddleware(opts: RateLimitOptions) {
  const redis = new RedisRateLimiter(opts.redisUrl || process.env.RATE_LIMIT_REDIS_URL || process.env.REDIS_URL || 'redis://localhost:6379');
  let initPromise: Promise<void> | null = null;
  async function ensure() {
    if (!initPromise) initPromise = redis.connect();
    return initPromise;
  }
  return async (req: FastifyRequest, reply: FastifyReply) => {
    await ensure();
    const routeUrl = (req as any).routeOptions?.url || req.url.split('?')[0];
    const tenant = (req as any).ctx?.orgId || req.headers['x-org-id'] || 'anon';
    const subject = (opts.keyFn ? opts.keyFn(req) : ((req as any).user?.userId || req.ip)) as string;
    const key = buildKey([tenant as string, routeUrl, req.method, subject]);
    const result = await redis.allow(key, opts.limit, opts.windowSeconds);
    const resetSec = result.retryAfterSeconds || 0;
    reply
      .header('X-RateLimit-Limit', opts.limit)
      .header('X-RateLimit-Remaining', Math.max(0, result.remaining ?? 0))
      .header('X-RateLimit-Reset', resetSec);
    if (!result.allowed) {
      reply.header('Retry-After', resetSec);
      return reply.code(429).type('application/problem+json').send({ type: 'urn:thankful:rate_limit:exceeded', title: 'rate_limit', status: 429, detail: `retry in ${resetSec}s`, trace_id: (req as any).ctx?.traceId });
    }
  };
}
