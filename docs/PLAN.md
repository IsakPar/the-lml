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


