export type RateLimitDecision = Readonly<{
    allowed: boolean;
    retryAfterSeconds?: number;
    remaining?: number;
    limit?: number;
}>;
export interface RateLimiterStore {
    incrAndGet(key: string, windowSec: number): Promise<{
        count: number;
        resetAt: number;
    }>;
}
export declare function buildKey(parts: Array<string | number>): string;
