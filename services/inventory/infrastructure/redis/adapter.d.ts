type AcquireResult = {
    ok: true;
} | {
    conflictKeys: string[];
};
type SimpleResult = 'OK' | 'NOOP';
export declare class RedisSeatLockAdapter {
    private client;
    private shaByName;
    constructor(redisUrl: string);
    connect(): Promise<void>;
    disconnect(): Promise<void>;
    loadScripts(): Promise<void>;
    private evalWithRetry;
    acquireAllOrNone(keys: string[], owner: string, version: number, ttlMs: number, nowMs?: number): Promise<AcquireResult>;
    extendIfOwner(key: string, owner: string, version: number, ttlMs: number, nowMs?: number): Promise<SimpleResult>;
    releaseIfOwner(key: string, owner: string, version: number): Promise<SimpleResult>;
    rollbackIfOwner(key: string, owner: string, version: number): Promise<SimpleResult>;
}
export declare function seatKey(tenantId: string, performanceId: string, seatId: string): string;
export {};
