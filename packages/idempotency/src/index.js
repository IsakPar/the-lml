import stringify from 'fast-json-stable-stringify';
export function canonicalHash({ method, path, contentType, body }) {
    const stable = stringify(body ?? null);
    const input = `${method}:${path}:${contentType}:${stable}`;
    // Simple hash for scaffold; replace with crypto subtle digest if needed
    let h = 0;
    for (let i = 0; i < input.length; i++)
        h = Math.imul(31, h) + input.charCodeAt(i) | 0; // eslint-disable-line no-bitwise
    return String(h >>> 0);
}
export function redisKey(route, tenant, key) {
    return `lml:idem:${route}:${tenant}:${key}`;
}
