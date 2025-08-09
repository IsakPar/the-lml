// Tables: users(id uuid pk, tenant_id uuid, email text unique per tenant, created_at, updated_at);
// api_keys(id uuid pk, tenant_id uuid, hash text, scopes text[], last_used_at timestamptz, created_at);
// roles(id uuid pk, tenant_id uuid, name text unique per tenant);
// user_roles(user_id uuid fk, role_id uuid fk, tenant_id uuid, unique(user_id, role_id) per tenant);
// Indexes/FKs: (tenant_id,email) unique; FKs named fk_user_roles_user, fk_user_roles_role.
// RLS: enabled on every table with USING/WITH CHECK via current_setting('app.tenant_id').
// Money: minor units int/bigint + currency CHAR(3).
