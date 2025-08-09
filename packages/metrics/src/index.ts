import { Registry, collectDefaultMetrics, Histogram, Counter } from 'prom-client';

// Singleton registry to avoid duplicate metric registration in monorepo/hot-reload
const globalKey = Symbol.for('thankful.metrics.registry');
const globalSymbols = global as unknown as Record<string | symbol, unknown>;

export function getRegistry(): Registry {
  if (!globalSymbols[globalKey]) {
    const registry = new Registry();
    collectDefaultMetrics({ register: registry });
    globalSymbols[globalKey] = registry;
  }
  return globalSymbols[globalKey] as Registry;
}

export function counter(config: ConstructorParameters<typeof Counter>[0]) {
  const reg = getRegistry();
  return new Counter({ registers: [reg], ...config });
}

export function histogram(config: ConstructorParameters<typeof Histogram>[0]) {
  const reg = getRegistry();
  return new Histogram({ registers: [reg], ...config });
}


