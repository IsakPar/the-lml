import type { IdempotencyRecord } from './index.js';

export interface RedisLike {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, mode: 'EX', ttlSec: number, flag?: 'NX' | 'XX'): Promise<'OK' | null>;
}

export function createIdemStore(client: RedisLike) {
  return {
    async get(key: string): Promise<IdempotencyRecord | null> {
      const v = await client.get(key);
      return v ? (JSON.parse(v) as IdempotencyRecord) : null;
    },
    async setPending(key: string, rec: IdempotencyRecord, ttlSec: number): Promise<boolean> {
      const res = await client.set(key, JSON.stringify(rec), 'EX', ttlSec, 'NX');
      return res === 'OK';
    },
    async finalize(key: string, updater: (prev: IdempotencyRecord) => IdempotencyRecord, ttlSec: number): Promise<void> {
      const prev = await this.get(key);
      if (!prev) return;
      const next = updater(prev);
      await client.set(key, JSON.stringify(next), 'EX', ttlSec, 'XX');
    }
  };
}



