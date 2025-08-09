import { createClient, RedisClientType } from 'redis';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { performance } from 'node:perf_hooks';
import { metrics } from '../../../../packages/metrics/src/index.js';

type AcquireResult = { ok: true } | { conflictKeys: string[] };
type SimpleResult = 'OK' | 'NOOP';

type ScriptName = 'acquire_all_or_none' | 'extend_if_owner' | 'release_if_owner' | 'rollback_if_owner';

export class RedisSeatLockAdapter {
  private client: RedisClientType;
  private shaByName: Record<ScriptName, string> = {
    acquire_all_or_none: '',
    extend_if_owner: '',
    release_if_owner: '',
    rollback_if_owner: ''
  };

  constructor(redisUrl: string) {
    this.client = createClient({ url: redisUrl, socket: { connectTimeout: 500 } });
  }

  async connect(): Promise<void> {
    if (!this.client.isOpen) {
      await this.client.connect();
    }
  }

  async disconnect(): Promise<void> {
    if (this.client.isOpen) {
      await this.client.quit();
    }
  }

  async loadScripts(): Promise<void> {
    await this.connect();
    try { await (this.client as any).scriptFlush('SYNC'); } catch {}
    const baseDir = resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua');
    const entries: Array<[ScriptName, string]> = [
      ['acquire_all_or_none', readFileSync(resolve(baseDir, 'acquire_all_or_none.lua'), 'utf8')],
      ['extend_if_owner', readFileSync(resolve(baseDir, 'extend_if_owner.lua'), 'utf8')],
      ['release_if_owner', readFileSync(resolve(baseDir, 'release_if_owner.lua'), 'utf8')],
      ['rollback_if_owner', readFileSync(resolve(baseDir, 'rollback_if_owner.lua'), 'utf8')]
    ];
    for (const [name, script] of entries) {
      const sha = await this.client.scriptLoad(script).catch(async (err: any) => {
        // SCRIPT LOAD might fail if scripts are disabled; fallback to eval later
        metrics.seat_lock_lua_errors_total.inc();
        throw err;
      });
      this.shaByName[name] = sha as string;
    }
  }

  private async evalWithRetry<T>(name: ScriptName, script: string, keys: string[], args: Array<string | number>): Promise<T> {
    const sha = this.shaByName[name];
    const maxAttempts = 3;
    const backoff = (i: number) => new Promise((r) => setTimeout(r, 10 * (i + 1)));
    const start = performance.now();
    let lastErr: any;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        const elapsed = performance.now() - start;
          if (elapsed > 150) {
          metrics.seat_lock_redis_timeouts_total.inc();
          throw new Error('redis_timeout_overall');
        }
        // Per-call budget ~50ms
        const callStart = performance.now();
        try {
          const res = await this.client.evalSha(sha, {
            keys,
            arguments: args.map(String)
          }) as T;
          const callElapsed = performance.now() - callStart;
          if (callElapsed > 50) {
            metrics.seat_lock_redis_timeouts_total.inc();
          }
          return res;
        } catch (err: any) {
          const msg = String(err?.message || err);
          if (msg.includes('NOSCRIPT') || msg.includes('script not found')) {
            // SCRIPT LOAD again and retry
            const newSha = await this.client.scriptLoad(script);
            this.shaByName[name] = newSha;
            continue;
          }
          if (msg.startsWith('BUSY') || msg.includes('LOADING')) {
            await backoff(attempt);
            continue;
          }
          // Fallback to EVAL once
          if (attempt === 0) {
            const res = await this.client.eval(script, {
              keys,
              arguments: args.map(String)
            }) as T;
            return res;
          }
          throw err;
        }
      } catch (e: any) {
        lastErr = e;
      }
    }
    metrics.seat_lock_lua_errors_total.inc();
    throw lastErr;
  }

  async acquireAllOrNone(keys: string[], owner: string, version: number, ttlMs: number, nowMs?: number): Promise<AcquireResult> {
    const scriptName: ScriptName = 'acquire_all_or_none';
    const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/acquire_all_or_none.lua'), 'utf8');
    const t0 = performance.now();
    const result = await this.evalWithRetry<any>(scriptName, script, keys, [owner, version, ttlMs, nowMs ?? Date.now()]);
    const dur = performance.now() - t0;
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ event: 'locks.acquire', durMs: Math.round(dur) }));
    try {
      const probeKey = keys[0];
      const val = await this.client.get(probeKey as string);
      const pttl = await (this.client as any).pTTL(probeKey as string);
      // eslint-disable-next-line no-console
      console.log(JSON.stringify({ event: 'locks.state', key: probeKey, val, pttl }));
    } catch {}
    if (Array.isArray(result) && result[0] === 'CONFLICT') {
      const conflictKeys = result.slice(1).map(String);
      metrics.seat_lock_acquire_conflict_total.inc();
      return { conflictKeys };
    }
    metrics.seat_lock_acquire_ok_total.inc();
    return { ok: true };
  }

  async extendIfOwner(key: string, owner: string, version: number, ttlMs: number, nowMs?: number): Promise<SimpleResult> {
    const scriptName: ScriptName = 'extend_if_owner';
    const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/extend_if_owner.lua'), 'utf8');
    const t0 = performance.now();
    const res = await this.evalWithRetry<string>(scriptName, script, [key], [owner, version, ttlMs, nowMs ?? Date.now()]);
    const dur = performance.now() - t0;
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ event: 'locks.extend', durMs: Math.round(dur) }));
    if (res === 'OK') metrics.seat_lock_extend_ok_total.inc();
    return res as SimpleResult;
  }

  async releaseIfOwner(key: string, owner: string, version: number): Promise<SimpleResult> {
    const scriptName: ScriptName = 'release_if_owner';
    const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/release_if_owner.lua'), 'utf8');
    const t0 = performance.now();
    const res = await this.evalWithRetry<string>(scriptName, script, [key], [owner, version, 0, Date.now()]);
    const dur = performance.now() - t0;
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ event: 'locks.release', durMs: Math.round(dur) }));
    if (res === 'OK') metrics.seat_lock_release_ok_total.inc();
    return res as SimpleResult;
  }

  async rollbackIfOwner(key: string, owner: string, version: number): Promise<SimpleResult> {
    const scriptName: ScriptName = 'rollback_if_owner';
    const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/rollback_if_owner.lua'), 'utf8');
    const t0 = performance.now();
    const res = await this.evalWithRetry<string>(scriptName, script, [key], [owner, version, 0, Date.now()]);
    const dur = performance.now() - t0;
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ event: 'locks.rollback', durMs: Math.round(dur) }));
    if (res === 'OK') metrics.seat_lock_rollback_ok_total.inc();
    return res as SimpleResult;
  }
}

export function seatKey(tenantId: string, performanceId: string, seatId: string): string {
  // Redis Cluster-friendly: hash-tag ensures same slot per tenant+performance
  return `hold:v1:{${tenantId}:${performanceId}}:${seatId}`;
}
// Script loading: load on boot; cache SHAs; fallback to EVAL after SCRIPT FLUSH.
// Invocation contracts per script:
// - KEYS ordering: acquire -> one key per seat; extend/release/rollback -> single key per call.
// - ARGV order: owner, version, ttl_ms, now_ms.
// Returns: "OK" | { conflictKeys: string[] } | "NOOP" (match Lua comments).
// Time source: now_ms comes from app; TTL via PSETEX.
// Metrics: acquire_ok, acquire_conflict, extend_ok, release_ok, rollback_ok, lua_error, redis_timeout.
// Errors: timeouts/network/non-OK -> typed errors bubbled to application.

// Concurrency & timeouts: per script call budget 50ms; retry up to 3 times with exponential backoff on BUSY; overall op budget 150ms.
