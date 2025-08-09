### ADR-000: Overall Architecture (DDD + Clean Architecture)

Context
- High-demand ticketing platform with strict consistency and performance targets.

Decision
- Monorepo (pnpm) with ESM, TypeScript project references.
- Clean Architecture per bounded context (`domain`, `application`, `interface`, `infrastructure`).
- Platform composition layer: `packages/platform/{api,worker}` wires ports→adapters; apps are thin shells.
- Public HTTP at `/api/v1/...`; RFC7807 errors; camelCase JSON; idempotency on all writes.

Consequences
- Layer boundaries enforce testability and swapability of adapters.
- Platform layer avoids composition root exceptions in ESLint boundaries.
- Versioned HTTP contracts allow additive evolution; breaking changes move to v2.



