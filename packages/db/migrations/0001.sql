-- 0001 bootstrap: schemas, extensions, helper GUC function, example table with RLS

-- Schemas
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS orders;
CREATE SCHEMA IF NOT EXISTS payments;
CREATE SCHEMA IF NOT EXISTS lml; -- helper schema

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;   -- for case-insensitive emails

-- Helper function so RLS does not error when tenant is unset
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

-- Example table for readiness tests and RLS
CREATE TABLE IF NOT EXISTS identity.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  email citext NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_email_tenant_uniq UNIQUE (tenant_id, email)
);

-- RLS: deny if tenant unset; isolate by tenant
ALTER TABLE identity.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.users FORCE ROW LEVEL SECURITY;

CREATE POLICY users_sel ON identity.users
  FOR SELECT USING (
    lml.current_tenant() IS NOT NULL AND tenant_id = lml.current_tenant()
  );

CREATE POLICY users_ins ON identity.users
  FOR INSERT WITH CHECK (
    tenant_id = lml.current_tenant()
  );

CREATE POLICY users_upd ON identity.users
  FOR UPDATE USING (
    tenant_id = lml.current_tenant()
  ) WITH CHECK (
    tenant_id = lml.current_tenant()
  );

CREATE POLICY users_del ON identity.users
  FOR DELETE USING (
    tenant_id = lml.current_tenant()
  );

