export function logger() {
    return { info: (_m, _f) => void 0 };
}
export function log(event, fields = {}) {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ event, ...fields }));
}
