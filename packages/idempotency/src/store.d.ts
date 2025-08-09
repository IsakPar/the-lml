import type { IdemState } from './store.port.js';
export interface RedisLike {
    get(key: string): Promise<string | null>;
    set(key: string, value: string, mode: 'EX', ttlSec: number, flag?: 'NX' | 'XX'): Promise<'OK' | null>;
}
export declare function createIdemStore(client: RedisLike): {
    get(key: string): Promise<IdemState>;
    begin(key: string, ownerRequestId: string, ttlSec: number): Promise<IdemState>;
    commit(key: string, meta: {
        status: number;
        headersHash: string;
        bodyHash: string;
    }, ttlSec: number): Promise<void>;
};
