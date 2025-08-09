Use-cases (spec):
- HoldSeats
  Input: { tenant, performanceId, seatIds, owner, ttlMs, nowMs }
  Ports used: SeatLockPort, HoldShadowRepo (append-only), ClockPort
  Invariants: all-or-none acquire; no oversell; ttlMs within configured max
  Output: success -> hold snapshot; conflict -> { seatIds }
- ExtendHold
  Input: { tenant, holdId, expectedVersion, ttlMs, nowMs }
  Invariants: only owner+version may extend; ceil ttl within max
  Output: success -> { holdId, expiresAt }
- ReleaseHold
  Input: { tenant, holdId, expectedVersion }
  Invariants: only owner+version may release; safe no-op if expired
  Failure modes: Conflict, NotFound, PreconditionFailed, Expired (typed)
  Idempotency: UC receives idempotency key (for correlation); store behavior handled by platform
  Telemetry: counters/timers for acquire/extend/release; conflict rate
- Constraints: owner length ≤ 128 chars; expectedVersion is a positive integer.
