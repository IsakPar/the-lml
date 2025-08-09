export function logger() {
  return { info: (_m: string, _f?: Record<string, unknown>) => void 0 };
}

export function log(event: string, fields: Record<string, unknown> = {}) {
  // eslint-disable-next-line no-console
  console.log(JSON.stringify({ event, ...fields }));
}



