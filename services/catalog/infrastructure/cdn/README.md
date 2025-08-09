Responsibilities: upload artifacts to object store, set cache headers, return CDN URLs; optional URL signing per tenant.
Tenancy: path prefix {tenant}/seatmaps/{venue}/{version}/…; no cross-tenant leakage.
Observability: later metrics (bundle size, upload duration, cache-hit ratio).
