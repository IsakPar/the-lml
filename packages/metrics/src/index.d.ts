import { Registry, Histogram, Counter } from 'prom-client';
export declare function getRegistry(): Registry;
export declare function counter(config: ConstructorParameters<typeof Counter>[0]): Counter<string>;
export declare function histogram(config: ConstructorParameters<typeof Histogram>[0]): Histogram<string>;
