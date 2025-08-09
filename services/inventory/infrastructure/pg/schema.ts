// Tables: holds_shadow(id uuid pk, tenant_id uuid, hold_id uuid, performance_id uuid, seats jsonb, owner text, version bigint, expires_at timestamptz, created_at);
// blocks(id uuid pk, tenant_id uuid, performance_id uuid, seat_id uuid, reason text, created_at);
// Indexes: (tenant_id, performance_id); (tenant_id, hold_id) for lookups; (tenant_id, performance_id, seat_id) unique in blocks.
// RLS: enabled on every table with USING/WITH CHECK via current_setting('app.tenant_id').
// Money: minor units int/bigint + currency CHAR(3).
// holds_shadow events: type in {ACQUIRED, EXTENDED, RELEASED, EXPIRED}.
// Indexes: (tenant_id, hold_id), (tenant_id, performance_id), optional GIN on seats for seat-based queries.
// RLS: writes occur under SET LOCAL app.tenant_id.
