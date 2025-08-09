import { Registry, collectDefaultMetrics, Histogram, Counter } from 'prom-client';
// Singleton registry to avoid duplicate metric registration in monorepo/hot-reload
const globalKey = Symbol.for('thankful.metrics.registry');
const globalSymbols = globalThis;
export function getRegistry() {
    if (!globalSymbols[globalKey]) {
        const registry = new Registry();
        collectDefaultMetrics({ register: registry });
        globalSymbols[globalKey] = registry;
    }
    return globalSymbols[globalKey];
}
export function counter(config) {
    const reg = getRegistry();
    return new Counter({ registers: [reg], ...config });
}
export function histogram(config) {
    const reg = getRegistry();
    return new Histogram({ registers: [reg], ...config });
}
// Built-in counters used across the repo
export const metrics = {
    // Seat locks
    seat_lock_acquire_ok_total: new Counter({ name: 'seat_lock_acquire_ok_total', help: 'Seat lock acquires that succeeded', registers: [getRegistry()] }),
    seat_lock_acquire_conflict_total: new Counter({ name: 'seat_lock_acquire_conflict_total', help: 'Seat lock acquire conflicts', registers: [getRegistry()] }),
    seat_lock_extend_ok_total: new Counter({ name: 'seat_lock_extend_ok_total', help: 'Seat lock extends that succeeded', registers: [getRegistry()] }),
    seat_lock_release_ok_total: new Counter({ name: 'seat_lock_release_ok_total', help: 'Seat lock releases that succeeded', registers: [getRegistry()] }),
    seat_lock_rollback_ok_total: new Counter({ name: 'seat_lock_rollback_ok_total', help: 'Seat lock rollbacks that succeeded', registers: [getRegistry()] }),
    seat_lock_lua_errors_total: new Counter({ name: 'seat_lock_lua_errors_total', help: 'Lua errors encountered', registers: [getRegistry()] }),
    seat_lock_redis_timeouts_total: new Counter({ name: 'seat_lock_redis_timeouts_total', help: 'Redis timeouts encountered', registers: [getRegistry()] }),
    // Idempotency
    idem_begin_total: new Counter({ name: 'idem_begin_total', help: 'Idempotency begin attempts', registers: [getRegistry()] }),
    idem_begin_conflict_total: new Counter({ name: 'idem_begin_conflict_total', help: 'Begin saw existing record', registers: [getRegistry()] }),
    idem_inprogress_202_total: new Counter({ name: 'idem_inprogress_202_total', help: 'In-progress duplicates returned 202', registers: [getRegistry()] }),
    idem_commit_total: new Counter({ name: 'idem_commit_total', help: 'Committed idempotent responses', registers: [getRegistry()] }),
    idem_hit_cached_total: new Counter({ name: 'idem_hit_cached_total', help: 'Cache hits on idempotent key', registers: [getRegistry()] }),
    idem_expired_total: new Counter({ name: 'idem_expired_total', help: 'Idempotent records expired (observed)', registers: [getRegistry()] })
};
export function serializeMetrics() {
    return Promise.resolve(getRegistry().metrics());
}
