export declare const metrics: {
    acquire_ok: import("prom-client").Counter<string>;
    acquire_conflict: import("prom-client").Counter<string>;
    extend_ok: import("prom-client").Counter<string>;
    release_ok: import("prom-client").Counter<string>;
    rollback_ok: import("prom-client").Counter<string>;
    lua_error: import("prom-client").Counter<string>;
    redis_timeout: import("prom-client").Counter<string>;
    idem_begin: import("prom-client").Counter<string>;
    idem_begin_conflict: import("prom-client").Counter<string>;
    idem_inprogress_202: import("prom-client").Counter<string>;
    idem_commit: import("prom-client").Counter<string>;
    idem_hit_cached: import("prom-client").Counter<string>;
    idem_expired: import("prom-client").Counter<string>;
};
export declare function serializeMetrics(): Promise<string>;
