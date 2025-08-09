// Rate limit subjects: IP + x-api-key (case-insensitive) + tenant; failure -> 429 RFC7807.
// Response headers: Retry-After (seconds), optionally X-RateLimit-Remaining (spec-only). Defaults: burst=10, window=60s.
