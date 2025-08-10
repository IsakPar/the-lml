import type { FastifyReply, FastifyRequest } from 'fastify';
import { type RateLimitDecision } from './port.js';
export type RateLimitOptions = Readonly<{
    limit: number;
    windowSeconds: number;
    redisUrl?: string;
    keyFn?: (req: FastifyRequest) => string;
}>;
export declare class RedisRateLimiter {
    private readonly url;
    private client;
    private ready;
    constructor(url: string);
    connect(): Promise<void>;
    allow(key: string, limit: number, windowSec: number): Promise<RateLimitDecision>;
}
export declare function createRateLimitMiddleware(opts: RateLimitOptions): (req: FastifyRequest, reply: FastifyReply) => Promise<undefined>;
