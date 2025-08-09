export type IdemState = {
    state: 'missing';
} | {
    state: 'in-progress';
    ownerRequestId: string;
    startedAt: number;
} | {
    state: 'committed';
    status: number;
    headersHash: string;
    bodyHash: string;
    createdAt: number;
};
export interface IdemStorePort {
    begin(key: string, ownerRequestId: string, ttlSec: number): Promise<IdemState>;
    get(key: string): Promise<IdemState>;
    commit(key: string, meta: {
        status: number;
        headersHash: string;
        bodyHash: string;
    }, ttlSec: number): Promise<void>;
}
