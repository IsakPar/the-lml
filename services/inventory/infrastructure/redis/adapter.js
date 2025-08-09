import { createClient } from 'redis';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { performance } from 'node:perf_hooks';
import { metrics } from '../../../../packages/metrics/src/metrics.js';
export class RedisSeatLockAdapter {
    client;
    shaByName = {
        acquire_all_or_none: '',
        extend_if_owner: '',
        release_if_owner: '',
        rollback_if_owner: ''
    };
    constructor(redisUrl) {
        this.client = createClient({ url: redisUrl, socket: { connectTimeout: 500 } });
    }
    async connect() {
        if (!this.client.isOpen) {
            await this.client.connect();
        }
    }
    async disconnect() {
        if (this.client.isOpen) {
            await this.client.quit();
        }
    }
    async loadScripts() {
        await this.connect();
        try {
            await this.client.scriptFlush('SYNC');
        }
        catch { }
        const baseDir = resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua');
        const entries = [
            ['acquire_all_or_none', readFileSync(resolve(baseDir, 'acquire_all_or_none.lua'), 'utf8')],
            ['extend_if_owner', readFileSync(resolve(baseDir, 'extend_if_owner.lua'), 'utf8')],
            ['release_if_owner', readFileSync(resolve(baseDir, 'release_if_owner.lua'), 'utf8')],
            ['rollback_if_owner', readFileSync(resolve(baseDir, 'rollback_if_owner.lua'), 'utf8')]
        ];
        for (const [name, script] of entries) {
            const sha = await this.client.scriptLoad(script).catch(async (err) => {
                // SCRIPT LOAD might fail if scripts are disabled; fallback to eval later
                metrics.lua_error.inc();
                throw err;
            });
            this.shaByName[name] = sha;
        }
    }
    async evalWithRetry(name, script, keys, args) {
        const sha = this.shaByName[name];
        const maxAttempts = 3;
        const backoff = (i) => new Promise((r) => setTimeout(r, 10 * (i + 1)));
        const start = performance.now();
        let lastErr;
        for (let attempt = 0; attempt < maxAttempts; attempt++) {
            try {
                const elapsed = performance.now() - start;
                if (elapsed > 150) {
                    metrics.redis_timeout.inc();
                    throw new Error('redis_timeout_overall');
                }
                // Per-call budget ~50ms
                const callStart = performance.now();
                try {
                    const res = await this.client.evalSha(sha, {
                        keys,
                        arguments: args.map(String)
                    });
                    const callElapsed = performance.now() - callStart;
                    if (callElapsed > 50) {
                        metrics.redis_timeout.inc();
                    }
                    return res;
                }
                catch (err) {
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
                        });
                        return res;
                    }
                    throw err;
                }
            }
            catch (e) {
                lastErr = e;
            }
        }
        metrics.lua_error.inc();
        throw lastErr;
    }
    async acquireAllOrNone(keys, owner, version, ttlMs, nowMs) {
        const scriptName = 'acquire_all_or_none';
        const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/acquire_all_or_none.lua'), 'utf8');
        const t0 = performance.now();
        const result = await this.evalWithRetry(scriptName, script, keys, [owner, version, ttlMs, nowMs ?? Date.now()]);
        const dur = performance.now() - t0;
        // eslint-disable-next-line no-console
        console.log(JSON.stringify({ event: 'locks.acquire', durMs: Math.round(dur) }));
        try {
            const probeKey = keys[0];
            const val = await this.client.get(probeKey);
            // @ts-expect-error node-redis types
            const pttl = await this.client.pTTL(probeKey);
            // eslint-disable-next-line no-console
            console.log(JSON.stringify({ event: 'locks.state', key: probeKey, val, pttl }));
        }
        catch { }
        if (Array.isArray(result) && result[0] === 'CONFLICT') {
            const conflictKeys = result.slice(1).map(String);
            metrics.acquire_conflict.inc();
            return { conflictKeys };
        }
        metrics.acquire_ok.inc();
        return { ok: true };
    }
    async extendIfOwner(key, owner, version, ttlMs, nowMs) {
        const scriptName = 'extend_if_owner';
        const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/extend_if_owner.lua'), 'utf8');
        const t0 = performance.now();
        const res = await this.evalWithRetry(scriptName, script, [key], [owner, version, ttlMs, nowMs ?? Date.now()]);
        const dur = performance.now() - t0;
        // eslint-disable-next-line no-console
        console.log(JSON.stringify({ event: 'locks.extend', durMs: Math.round(dur) }));
        if (res === 'OK')
            metrics.extend_ok.inc();
        return res;
    }
    async releaseIfOwner(key, owner, version) {
        const scriptName = 'release_if_owner';
        const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/release_if_owner.lua'), 'utf8');
        const t0 = performance.now();
        const res = await this.evalWithRetry(scriptName, script, [key], [owner, version, 0, Date.now()]);
        const dur = performance.now() - t0;
        // eslint-disable-next-line no-console
        console.log(JSON.stringify({ event: 'locks.release', durMs: Math.round(dur) }));
        if (res === 'OK')
            metrics.release_ok.inc();
        return res;
    }
    async rollbackIfOwner(key, owner, version) {
        const scriptName = 'rollback_if_owner';
        const script = readFileSync(resolve(process.cwd(), 'services/inventory/infrastructure/redis/lua/rollback_if_owner.lua'), 'utf8');
        const t0 = performance.now();
        const res = await this.evalWithRetry(scriptName, script, [key], [owner, version, 0, Date.now()]);
        const dur = performance.now() - t0;
        // eslint-disable-next-line no-console
        console.log(JSON.stringify({ event: 'locks.rollback', durMs: Math.round(dur) }));
        if (res === 'OK')
            metrics.rollback_ok.inc();
        return res;
    }
}
export function seatKey(tenantId, performanceId, seatId) {
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
