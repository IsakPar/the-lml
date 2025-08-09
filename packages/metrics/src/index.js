import { Registry, collectDefaultMetrics, Histogram, Counter } from 'prom-client';
// Singleton registry to avoid duplicate metric registration in monorepo/hot-reload
const globalKey = Symbol.for('thankful.metrics.registry');
const globalSymbols = global;
export function getRegistry() {
    if (!globalSymbols[globalKey]) {
        const registry = new Registry();
        collectDefaultMetrics({ register: registry });
        globalSymbols[globalKey] = registry;
    }
    return globalSymbols[globalKey];
}
export function counter(config) {
    const reg = getRegistry();
    return new Counter({ registers: [reg], ...config });
}
export function histogram(config) {
    const reg = getRegistry();
    return new Histogram({ registers: [reg], ...config });
}
