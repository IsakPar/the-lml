## DDD Architecture Audit (Initial Pass)

### Observations

- Services scaffolding exists but many files are placeholders (e.g., `services/catalog/infrastructure/mongo/repo.ts`). This creates confusion and adds perceived technical debt.
- There are real implementations in key paths:
  - Inventory seat locking has a concrete Redis adapter with Lua scripts: `services/inventory/infrastructure/redis/adapter.ts` and `services/inventory/infrastructure/redis/lua/*`.
  - Identity includes a fully fleshed use case `AuthenticateUser` under application layer.
  - API layer follows Clean Architecture, exposing routes in `apps/api/src/v1/...` and wiring ports/adapters.
- Some “domain/application” folders are skeletal, likely intended as future bounded contexts, but currently unused.

### Risks

- Placeholder files dilute signal-to-noise and hinder discoverability.
- Violations of “one public export per file” are rare but stubs can tempt ad-hoc additions over time.
- Incomplete contexts risk accidental cross-context coupling later.

### Recommendations (Actionable)

1) Remove empty files; keep only README stubs
   - Replace empty `.ts` with a short `README.md` explaining intended responsibilities and current status.
   - Benefit: reduces noise; keeps architectural intent.

2) Enforce minimal DDD skeleton per context
   - For each active context, ensure only these live folders exist: `domain`, `application`, `infrastructure`, `interface` (optional).
   - Remove unused layers until needed; re‑add via ADR when work begins.

3) Document allowed dependencies per layer (brief CODEOWNERS-style rules)
   - Add a `docs/architecture/layers.md` with import rules and examples.
   - Complement with an eslint import rule to enforce boundaries.

4) Promote real implementations out of API into services where appropriate
   - Example: Move seat hold verification policy into an `inventory` application use case with a port to Redis adapter.
   - Keep API as interface layer that orchestrates use cases only.

5) Tests as living contracts
   - Add unit tests to `services/*/application` to codify use case behavior; integration tests to `infrastructure` adapters.
   - Keep e2e limited to happy paths per context.

6) ADRs for deferred contexts
   - Create a brief ADR per placeholder context explaining scope, reason for deferral, and criteria to start.

### Proposed Remediation Plan (2 steps)

- Step A (Cleanup: 0.5–1 day)
  - Remove empty `.ts` files in services; add concise `README.md` placeholders.
  - Add `docs/architecture/layers.md` and update root README with rules.
  - Add eslint import boundaries for `domain`/`application`/`infrastructure`.

- Step B (Consolidate active flows: 1–2 days)
  - Extract order creation hold verification into `inventory` use case; API calls use case.
  - Add tests for the use case and Redis adapter interactions.
  - Add ADRs for dormant contexts stating intent and “not yet implemented”.

### Acceptance Criteria

- No empty source files remain; placeholders are documented in README.md only.
- Layer boundaries enforced via lint rule and docs.
- Inventory hold verification exists as an application use case with a port; route composes it.
- Tests cover use case behavior and adapter integration.


