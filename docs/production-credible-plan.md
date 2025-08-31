## Production-Credible Plan (Phased)

Goal: Evolve from solid base to production-credible by hardening tests, CI, boundaries, and ops.

### Phase 1 — Testing and Coverage (Week 1)
- Deliverables:
  - Unit tests for domain/application (holds, orders idempotency, verification) — no DB/network/time.
  - Integration tests per service (API + Redis/Postgres) via compose; negative and concurrency paths.
  - Coverage report uploaded in CI; coverage gate set to ≥ 50%.
- Checkpoints:
  - Domain unit suite green with deterministic stubs for time/UUID.
  - Integration suite spins Redis/Postgres via compose and runs migrations on a throwaway DB.
  - CI fails if coverage < 50%.

### Phase 2 — Boundary Enforcement (Week 1–2)
- Deliverables:
  - ESLint import-boundary rules (no cross-context imports; `domain` has zero framework/infra imports).
  - Extract inventory hold verification into `application` use case with `SeatLockPort`.
  - Interface layer calls use cases only; infra adapters wired at a single composition point.
- Checkpoints:
  - No violations on lint run.
  - Orders/inventory routes depend on ports, not concrete infra.

### Phase 3 — CI Hardening (Week 2)
- Deliverables:
  - CI pipeline: install → lint → typecheck → unit → integration (spin dev stack) → coverage gate.
  - Migrations run against a fresh DB per CI job.
  - Artifacts: coverage, junit reports.
- Checkpoints:
  - CI red on lint/type errors or coverage < threshold.
  - Parallelized jobs complete under target time budget.

### Phase 4 — DX and Docs (Week 2)
- Deliverables:
  - README “10‑minute quickstart.”
  - One architecture diagram (bounded contexts + clean layers).
  - CONTRIBUTING: naming, layering, testing strategy, expand→migrate→contract DB protocol.
- Checkpoints:
  - Newcomer can clone → run → pass tests in < 10 minutes.

### Phase 5 — Observability & Ops (Week 3)
- Deliverables:
  - Standardized logs (service, context, correlationId, event, severity) and key counters.
  - Latency histograms (p50/p95) and error rate on hot paths.
  - Health/readiness endpoints for all services wired into compose/CI.
- Checkpoints:
  - Local dashboard exposes request rate, latency, errors.
  - Liveness/readiness used by CI and local dev stack.

### Ratchet Plan (Ongoing)
- Increase coverage gate by +5% per sprint until 80%.
- Add ADRs for key decisions (ports, tenancy, persistence) as they occur.
- Consider contract tests for cross-service APIs after Phase 3.

### Success Criteria
- All CI gates enforced and green (lint, typecheck, unit, integration, ≥50% coverage).
- No boundary violations; domain is framework-free.
- Docs enable a new contributor to be productive in one session.
- Basic observability in place with traceable request IDs and latency/error metrics.


