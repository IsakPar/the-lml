// Inventory API (Holds) — final endpoints (spec only)
// Headers required: x-tenant-id (case-insensitive), Idempotency-Key (mutations only, min length 8); x-api-key participates in rate limit subjects when present.
// Validation (zod):
//  - seatIds: array length 1..25 (HOLD_MAX_SEATS_PER_REQUEST=25)
//  - seatId, performanceId, holdId: UUIDv4
//  - ttlMs: default 120_000, min 10_000, max 300_000 (from env)
//  - expectedVersion: positive integer
// Errors: RFC7807 with stable URNs (see docs/errors/inventory-holds.md)
// Observability: log/trace { tenant, request_id, performanceId, holdId }
//
// POST /performances/:performanceId/holds -> 201 / 409 / 422 (requires Idempotency-Key)
// Request body: { seats: string[], ttlMs?: number }
// Responses:
//  - 201 { holdId, performanceId, seatIds, owner, version, expiresAt }
//  - 409 { conflictSeatIds: string[] }
//  - 422 RFC7807 (validation / missing Idempotency-Key)
//
// PATCH /holds/:holdId (extend) -> 200 / 404 (requires Idempotency-Key)
// Request body: { ttlMs: number, expectedVersion: number }
// Response: { holdId, expiresAt }
//
// DELETE /holds/:holdId -> 204 / 404 (requires Idempotency-Key)
// Response: empty (204) on success; 404 if not found
//
// RFC7807 type URNs:
//  - urn:lml:platform:invalid-idempotency-key (422)
//  - urn:lml:inventory:validation (422)
//  - urn:lml:inventory:conflict (409)
//  - urn:lml:inventory:not-found (404)
