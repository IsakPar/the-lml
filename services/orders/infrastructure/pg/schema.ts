// Tables: orders(id uuid pk, tenant_id uuid, status text, total_minor bigint, currency char(3), created_at, updated_at);
// order_items(id uuid pk, tenant_id uuid, order_id uuid fk, seat_id uuid, price_minor bigint, currency char(3));
// order_audit_log(id bigserial pk, tenant_id uuid, order_id uuid fk, action text, data jsonb, created_at);
// Indexes: (tenant_id,status), (tenant_id,order_id) on items, FKs fk_items_order, fk_audit_order.
// RLS: enabled on every table with USING/WITH CHECK via current_setting('app.tenant_id').
// Money: minor units int/bigint + currency CHAR(3).
