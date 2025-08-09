// Wiring order (spec): request-id -> tenant -> rate-limit (noop now) -> idempotency-required (mutations) -> routes.
// Exclusions: /livez, /readyz, /metrics are not rate-limited and do not require Idempotency-Key.
// CORS/Auth: placeholders to insert auth before mutations in future iterations.
