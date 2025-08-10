export type RateLimitDecision = Readonly<{
  allowed: boolean;
  retryAfterSeconds?: number;
  remaining?: number;
  limit?: number;
}>;

export interface RateLimiterStore {
  incrAndGet(key: string, windowSec: number): Promise<{ count: number; resetAt: number }>;
}

export function buildKey(parts: Array<string | number>): string {
  return parts.filter(Boolean).join(':');
}
// Rate limit port + planned algorithms (sliding window / token bucket)
