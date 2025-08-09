Ports (spec):
- SeatLockPort
  Methods:
   * acquireSeats(tenant, performanceId, seatIds, owner, version, ttlMs, nowMs) -> "OK" | { conflictSeatIds: string[] }
   * extendHold(tenant, holdKey, owner, version, ttlMs, nowMs) -> "OK" | "NOOP"
   * releaseHold(tenant, holdKey, owner, version) -> "OK" | "NOOP"
  Contracts: align with Redis Lua return contracts; timeouts enforced per adapter spec
- HoldShadowRepo
  Methods:
   * append(tenant, event) where event.type ∈ {ACQUIRED, EXTENDED, RELEASED, EXPIRED}
   * getByHoldId(tenant, holdId) -> event stream snapshot
  Behavior: append-only; reads reconstruct state
