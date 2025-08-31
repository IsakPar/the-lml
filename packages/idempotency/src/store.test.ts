import { describe, it, expect } from 'vitest';
import { createIdemStore } from './store.js';

type Entry = string | null;

describe('createIdemStore', () => {
  it('begins, caches commit, and replays committed state', async () => {
    const mem = new Map<string, Entry>();
    const client = {
      get: async (k: string) => (mem.has(k) ? (mem.get(k) as string) : null),
      set: async (k: string, v: string, _mode: 'EX', _ttl: number, flag?: 'NX' | 'XX') => {
        if (flag === 'NX' && mem.has(k)) return null as const;
        if (flag === 'XX' && !mem.has(k)) return null as const;
        mem.set(k, v);
        return 'OK' as const;
      }
    };
    const store = createIdemStore(client);
    const key = 'idem:test:1';
    const first = await store.begin(key, 'req1', 60);
    expect(first.state).toBe('in-progress');
    await store.commit(key, { status: 201, headersHash: 'h', bodyHash: 'b', responseBody: JSON.stringify({ ok: true }) }, 3600);
    const again = await store.begin(key, 'req2', 60);
    expect(again.state).toBe('committed');
    expect(again.status).toBe(201);
  });
});
