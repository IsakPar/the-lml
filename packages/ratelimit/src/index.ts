export type RateLimitResult = Readonly<{
  allowed: boolean;
  retryAfterSeconds?: number;
  remaining?: number;
}>;

export interface RateLimiterPort {
  allow(route: string, tenant: string, subject: string, limit: number, windowSec: number): Promise<RateLimitResult>;
}



