# LML MVP Readiness – Remediation Plan

This document tracks all issues identified in the audit and our concrete plan to fix them, with priorities, acceptance criteria, and test coverage.

## Legend
- Priority: P1 (critical), P2 (high), P3 (normal)
- Owner: Platform (API/Auth/Infra), Inventory, Identity, Venues
- DoD: Definition of Done

---

## 1) Security: Postgres Row‑Level Security (RLS)
- Priority: P1
- Owner: Platform
- Why: DB‑level tenant isolation safety net; prevents cross‑org data leaks if app code misses filters.
- Plan:
  - Enable RLS on all tenant tables (identity, venues, inventory, orders, payments).
  - Use helper `lml.current_tenant()` and `SET LOCAL app.tenant_id` in a shared `withTenant(tenantId, fn)` wrapper.
  - Add policies: SELECT/INSERT/UPDATE/DELETE must match `tenant_id = lml.current_tenant()`.
- DoD:
  - Migration adds RLS + policies per table; adapter exposes `withTenant`; all repos use it.
  - Negative tests: cross‑org queries return zero rows even if a filter is omitted.
- Tests:
  - Unit: `withTenant` sets GUC; policy checks succeed/fail correctly.
  - Integration: two tenants seeded; ensure isolation.

## 2) Idempotency for mutating routes
- Priority: P1
- Owner: Platform, Inventory
- Why: Prevent duplicate processing on retries; exactly‑once UX and integrity.
- Status: POST `/v1/holds` now stores and replays committed response; 202 for in‑progress.
- Plan:
  - Apply the same middleware/store to all other mutating routes as they are implemented (e.g., carts, allocations, pricing updates).
  - Persist response body hash + body; set TTLs; add metrics (begin/commit/hit_cached).
- DoD:
  - Duplicate POST returns 202 (pending) or cached payload (status of original).
  - Metrics counters visible in `/metrics`.
- Tests:
  - Parallel duplicate requests: one processes, the other 202 then replay; replay after success.

## 3) Concurrency: fencing token on extend/release
- Priority: P2
- Owner: Inventory
- Status: PATCH/DELETE `/v1/holds` now require `hold_token` or `If-Match`; 412 Precondition when missing.
- Plan:
  - Standardize Problem+JSON for 412 with stable `type`.
  - Document header usage and examples.
- DoD: Wrong/missing token never mutates; correct token succeeds; SSE emitted.
- Tests: Wrong token → 412; expired token → 412; correct token → 200/204.

## 4) Multi‑seat atomicity (holds)
- Priority: P2
- Owner: Inventory
- Status: Redis Lua path supports all‑or‑none for multiple KEYS.
- Plan: Document contract; add tests for partial conflicts returning 409 + conflicting seats.
- DoD: Multi‑seat acquire is atomic; conflicts enumerated.
- Tests: Multi‑seat success; multi‑seat conflict set.

## 5) Availability + SSE
- Priority: P2
- Owner: Inventory, Venues
- Status: Snapshot endpoint implemented (Mongo seatmap + Redis lock scan); SSE emits events on lock/release.
- Plan:
  - Enrich SSE events with `expires_at` and `sales_channel_id` on both lock/release.
  - Support GA pools (zone‑level counts); strong ETags per snapshot inputs.
  - Optional debouncing/batching of SSE.
- DoD: Snapshot shows correct seats/zones; SSE shows real‑time changes with enriched payloads.
- Tests: Snapshot math property tests; SSE happy‑path; GA zone counters.

## 6) Scope/Authorization checks
- Priority: P1
- Owner: Platform
- Status: Holds routes guarded with `inventory.holds:write`.
- Plan:
  - Declare required scopes per route group (venues.read, identity.me.read, inventory.holds:write, etc.).
  - Ensure client_credentials vs user tokens enforce different capabilities.
- DoD: Requests without scope return 403; happy‑path succeeds with scope.
- Tests: Insufficient scope → 403; proper scope → 2xx.

## 7) OAuth2.1 polish (password grant, brute‑force)
- Priority: P2
- Owner: Identity, Platform
- Plan:
  - Add per‑user/IP rate limit on `/v1/oauth/token` password grant; include `Retry-After`.
  - Validate JWT `iss`/`aud`/`alg` allowlist; plan Auth Code + PKCE to replace password grant for non‑first‑party.
- DoD: Token endpoint throttled and returns standard headers; JWT validation hardened.
- Tests: RL triggers on repeated bad passwords; valid grants unaffected.

## 8) Rate limiting (headers, per‑route, distributed)
- Priority: P2
- Owner: Platform
- Status: X‑RateLimit headers present.
- Plan:
  - Per‑route budgets (stricter for token issuance and mutating routes); key by `{orgId|userId}+route+method`.
  - Move counters to Redis for multi‑instance.
- DoD: Correct headers for remaining/limit/reset; differentiated budgets; consistent 429.
- Tests: Header values correct; limits enforced per route.

## 9) Observability (metrics/tracing)
- Priority: P3
- Owner: Platform
- Plan:
  - Prometheus `prom-client`: HTTP request counters and latency histograms per route; domain counters (holds ok/conflict, idem begin/commit/hit).
  - OpenTelemetry: Root span per request; spans for Redis/Mongo/PG.
  - Dashboards + basic alerts (p95 latency, error rate, holds conflict rate).
- DoD: `/metrics` exposes above; traces produced locally (flagged in prod later).
- Tests: Scrape `/metrics` shows counters; manual trace check.

## 10) Testing & CI improvements
- Priority: P2
- Owner: Platform, Inventory
- Plan:
  - Add concurrency/idempotency/SSE/RLS tests; fix any flakiness.
  - Add k6 smoke for holds; CDC tests from OpenAPI.
- DoD: CI green with expanded suites; coverage trend improves; CDC gates on PR.

## 11) Mongo seatmap tenant binding
- Priority: P2
- Owner: Venues
- Plan:
  - Add `orgId` to seatmap docs in importer; require match with `X-Org-ID` on fetch.
  - Index (`orgId`, `_id`).
- DoD: Cross‑org fetch forbidden; tested.

## 12) Ops hardening (startup/health/shutdown)
- Priority: P3
- Owner: Platform
- Plan: DB/Redis/Mongo retry on boot; compose healthchecks; readyz reflects dependencies; graceful shutdown waits for in‑flight requests.
- DoD: Robust startup; clean shutdown; `/readyz` accurate.

## 13) CI/CD & dependency hygiene
- Priority: P3
- Owner: Platform
- Plan: Add `pnpm audit`/Dependabot; CodeQL; enforce build/typecheck/lint/tests/CDC gates.
- DoD: CI fails on known vulns; PRs blocked on gates.

## 14) JWT validation hardening
- Priority: P2
- Owner: Platform
- Plan: Enforce `iss`, `aud`, `alg` allowlist; optional `kid` rotation path.
- DoD: Tokens with wrong `iss/aud/alg` rejected; tests added.

## 15) Documentation
- Priority: P3
- Owner: Platform
- Plan: Update API docs for idempotency usage, `If-Match` fencing, required headers, scopes, rate limits, SSE event formats; changelog on contract changes.
- DoD: Docs published; examples consistent with behavior.

---

## Sequencing & Timeline (7–10 days)
- Days 1–3 (P1 first):
  - RLS across tables + adopt `withTenant` in repos.
  - Scope guards across protected routes.
  - Idempotency complete for POST `/v1/holds` (done) and reuse pattern for upcoming writes.
  - `/v1/oauth/token` rate limit + standard headers; JWT `iss/aud` checks.
- Days 4–7:
  - Availability: GA pools, enriched SSE (`expires_at`, `sales_channel_id`), debouncing; tests.
  - Tests: concurrency/idempotency/SSE/RLS; k6 smoke for holds.
  - Observability: Prometheus metrics for HTTP + domain; basic OpenTelemetry.
  - Mongo seatmap org binding + tests.
- Days 8–10:
  - CI audit/CodeQL; CDC tests from OpenAPI.
  - Ops: startup retries, healthchecks, graceful shutdown.
  - Docs refresh and examples; bug bash and small performance passes.

---

## Current Status (updated)
- Availability snapshot: implemented (seatmap + Redis) with ETag.
- SSE: emits lock/release; enrichment pending.
- Idempotency (holds): 202 for in‑progress; committed responses replayed.
- Fencing: `If-Match`/`hold_token` required on extend/release; 412 when missing.
- `/v1/status`: implemented with `Cache-Control: no-store`.
- `withTenant`: added in Postgres adapter; initial RLS migration scaffolded.

---

## Acceptance Artifacts
- Test IDs and Given/When/Then scenarios included alongside tests in `tests/**`.
- Metrics list documented in `packages/metrics/`.
- OpenAPI v1 with headers, Problem+JSON, and SSE event schemas.

---

## Risks & Mitigations
- RLS rollout: start permissive, verify, then enforce `FORCE RLS`.
- SSE volume: batch/debounce; keep heartbeats.
- Multi‑instance: migrate RL + idempotency to Redis‑backed primitives.
### Phased Repo Plan (DDD + Clean Architecture, pnpm monorepo)

Preconditions
- Node 20+, pnpm via Corepack, Docker Desktop running
- ESM only; TypeScript project references; pnpm workspaces

Phase 0 — Workspace & Guardrails (Day 0)
- Deliverables
  - `pnpm-workspace.yaml`, root `package.json` (ESM), root `tsconfig.json` (project refs)
  - Prettier/ESLint with boundaries; Husky + lint-staged hooks
  - packages/: `config` (zod + cross-field checks), `result`, `logging` (ALS-aware), `metrics` (singleton), `tracing`
  - ops/dev/docker-compose.yml (Postgres/Redis/Mongo) + `pnpm dev:stack:up`
- Acceptance
  - `pnpm -w build` green; API stubs expose `/livez`, `/readyz`, `/metrics`

Phase 1 — Platform Shells & Health (Day 0–1)
- Deliverables
  - `packages/platform/api` (Fastify) with `/livez`, `/readyz`, `/metrics`, route‑scoped raw‑body for Stripe webhooks
  - `packages/platform/worker` skeleton (idles, exports metrics)
  - `apps/api`, `apps/worker` thin wrappers
- Acceptance
  - API boots; Worker boots; probes 200; metrics visible

Phase 2 — Context Shells (Day 1)
- Deliverables
  - `services/{seating,ordering,payments,catalog}` with `domain/`, `application/`, `infrastructure/`, `fakes/` and one compile‑proof example per layer
  - ESLint boundaries enforce layer rules; packages/** never import services/**
- Acceptance
  - `pnpm -w typecheck` green; boundary lints enforced

Phase 3 — Data Layer & Migrations (Day 1–2)
- Deliverables
  - `packages/migrations`: Umzug runner + `sql/0001_core.sql` (events, event_seats, orders, order_lines, stripe_events, order_audit_log)
  - PG pool/timeouts: `statement_timeout`, `lock_timeout`, `idle_in_transaction_session_timeout`
- Acceptance
  - `pnpm migrate:dev` applies cleanly; `pnpm migrate:status` up‑to‑date

Phase 4 — Idempotency & Rate‑limit (Day 2)
- Deliverables
  - `packages/idempotency`: canonical JSON hashing, Redis store, Fastify middleware; 24h TTL; body mismatch → 409 RFC7807
  - `packages/ratelimit`: Redis Lua sliding window + token bucket; per‑route middleware
- Acceptance
  - Unit tests; integration: same key same body → replay; different body → 409; rate limit → 429 with Retry‑After

Phase 5 — Seating Locks (Day 2–3)
- Deliverables
  - Redis Lua: acquire_all_or_none, extend_if_owner, release_if_owner, rollback_if_owner
  - PG version bump on hold (sorted) and reserve asserts (ownership + version)
- Acceptance
  - Integration: forced PG bump failure → Redis rollback removes keys; extend beyond max → 422

Phase 6 — Payments Outbox & Worker (Day 3)
- Deliverables
  - Outbox processing for `stripe_events`: SKIP LOCKED claim; attempts/next_attempt_at/last_error; exp backoff + jitter; DLQ
  - Metrics: outbox lag; processed/failed by type; inflight gauges
- Acceptance
  - Integration: insert fake success event + pending order → order confirmed; seats paid; processed=true

Phase 7 — CI & Quality Gates (Day 3)
- Deliverables
  - CI: build, lint, typecheck, unit tests, integration (Testcontainers)
  - CODEOWNERS; branch protections; `migrate:prod` env guard
- Acceptance
  - CI green; integration job spins containers and passes

Definition of Done
- All phases’ acceptance checks green. `/readyz` checks DB/Redis/Mongo and Stripe secret (no external calls). ESLint boundaries enforce Clean Architecture.


