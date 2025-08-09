// POST /seatmaps (201/422) requires Idempotency-Key
// GET /seatmaps/:id (200/404)
// GET /performances/:id/overlay (200/304) -> { inventory_version, seats: Array<{ seatId, state, bandId? }> }, short TTL + ETag, API only (not CDN).
