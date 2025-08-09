import type { FastifyPluginCallback } from 'fastify';
export type RedisClient = {
    get(key: string): Promise<string | null>;
    set(key: string, value: string, mode: 'EX', ttlSec: number, flag?: 'NX' | 'XX'): Promise<'OK' | null>;
};
export declare const idempotencyMiddleware: FastifyPluginCallback<{
    client: RedisClient;
    tenant: string;
    routeKey: string;
    ttlSec: number;
}>;
