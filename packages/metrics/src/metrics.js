import { counter, getRegistry } from './index.js';
export const metrics = {
    acquire_ok: counter({ name: 'seat_lock_acquire_ok_total', help: 'Seat lock acquires that succeeded' }),
    acquire_conflict: counter({ name: 'seat_lock_acquire_conflict_total', help: 'Seat lock acquire conflicts' }),
    extend_ok: counter({ name: 'seat_lock_extend_ok_total', help: 'Seat lock extends that succeeded' }),
    release_ok: counter({ name: 'seat_lock_release_ok_total', help: 'Seat lock releases that succeeded' }),
    rollback_ok: counter({ name: 'seat_lock_rollback_ok_total', help: 'Seat lock rollbacks that succeeded' }),
    lua_error: counter({ name: 'seat_lock_lua_errors_total', help: 'Lua errors encountered' }),
    redis_timeout: counter({ name: 'seat_lock_redis_timeouts_total', help: 'Redis timeouts encountered' }),
    // Idempotency
    idem_begin: counter({ name: 'idem_begin_total', help: 'Idempotency begin attempts' }),
    idem_begin_conflict: counter({ name: 'idem_begin_conflict_total', help: 'Begin saw existing record' }),
    idem_inprogress_202: counter({ name: 'idem_inprogress_202_total', help: 'In-progress duplicates returned 202' }),
    idem_commit: counter({ name: 'idem_commit_total', help: 'Committed idempotent responses' }),
    idem_hit_cached: counter({ name: 'idem_hit_cached_total', help: 'Cache hits on idempotent key' }),
    idem_expired: counter({ name: 'idem_expired_total', help: 'Idempotent records expired (observed)' })
};
export function serializeMetrics() {
    return Promise.resolve(getRegistry().metrics());
}
// Prometheus registry singleton + default metrics
