DB package

Implements withTenant(tenantId, fn) transactional wrapper (SET LOCAL app.tenant_id) and exposes no raw getClient to callers. Repositories must accept a client provided by withTenant.

Migrations: keep Drizzle journal at packages/db/migrations/meta/_journal.json. Use migration 0001 to create schemas per context, identity.users with tenant_id, and enable RLS + tenant policy.

Local: set DATABASE_URL in .env; run `pnpm migrate:dev` (see repo root scripts) to apply.

