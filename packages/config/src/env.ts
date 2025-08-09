// Env additions:
// BLOB_BUCKET, BLOB_BASE_URL, CDN_BASE_URL, CDN_SIGNING_ENABLED (bool), CDN_SIGNING_KEY (optional).
// Overlays are not served via CDN.

// Holds & infra limits:
// HOLD_TTL_MS_DEFAULT (e.g., 120000), HOLD_TTL_MS_MAX (e.g., 300000)
// REDIS_COMMAND_TIMEOUT_MS (e.g., 100)
// IDEMPOTENCY_TTL_HOURS (e.g., 24)
// Validation: default <= max; positive integers
// Additional knobs:
// HOLD_MAX_SEATS_PER_REQUEST=25
// HOLD_OWNER_ID_MAX_LENGTH=128
// OVERLAY_TTL_SECONDS=5
// CDN_SIGNING_DEFAULT_TTL_SECONDS=600
// RATE_LIMIT_BURST=10, RATE_LIMIT_WINDOW_SECS=60
