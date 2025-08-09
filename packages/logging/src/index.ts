import { AsyncLocalStorage } from 'node:async_hooks';

type Ctx = { correlationId?: string; userId?: string };
const als = new AsyncLocalStorage<Ctx>();

export function runWithContext<T>(ctx: Ctx, fn: () => T): T {
  return als.run(ctx, fn);
}

export function getContext(): Ctx {
  return als.getStore() ?? {};
}

export function log(event: string, fields: Record<string, unknown> = {}) {
  const ctx = getContext();
  // eslint-disable-next-line no-console
  console.log(JSON.stringify({ event, ...ctx, ...fields }));
}



