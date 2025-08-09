import type { IdemState } from './store.port.js';
import { metrics } from '@thankful/metrics';

export interface RedisLike {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, mode: 'EX', ttlSec: number, flag?: 'NX' | 'XX'): Promise<'OK' | null>;
}

export function createIdemStore(client: RedisLike) {
  return {
    async get(key: string): Promise<IdemState> {
      const v = await client.get(key);
      return v ? (JSON.parse(v) as IdemState) : { state: 'missing' };
    },
    async begin(key: string, ownerRequestId: string, ttlSec: number): Promise<IdemState> {
      metrics.idem_begin_total.inc();
      const pending: IdemState = { state: 'in-progress', ownerRequestId, startedAt: Date.now() };
      const ok = await client.set(key, JSON.stringify(pending), 'EX', ttlSec, 'NX');
      if (ok === 'OK') return pending;
      const existing = await this.get(key);
      if (existing.state === 'committed') metrics.idem_hit_cached_total.inc();
      else if (existing.state === 'in-progress') metrics.idem_begin_conflict_total.inc();
      return existing;
    },
    async commit(key: string, meta: { status: number; headersHash: string; bodyHash: string }, ttlSec: number): Promise<void> {
      const committed: IdemState = { state: 'committed', status: meta.status, headersHash: meta.headersHash, bodyHash: meta.bodyHash, createdAt: Date.now() };
      await client.set(key, JSON.stringify(committed), 'EX', ttlSec, 'XX');
      metrics.idem_commit_total.inc();
    }
  };
}



