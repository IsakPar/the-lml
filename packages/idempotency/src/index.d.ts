export type IdempotencyRecord = Readonly<{
    status: 'pending' | 'done';
    resourceId?: string;
    httpStatus?: number;
    bodyHash: string;
    contentType: string;
    method: string;
    path: string;
    expiresAt: number;
}>;
export declare function canonicalHash({ method, path, contentType, body }: {
    method: string;
    path: string;
    contentType: string;
    body: unknown;
}): string;
export declare function redisKey(route: string, tenant: string, key: string): string;
