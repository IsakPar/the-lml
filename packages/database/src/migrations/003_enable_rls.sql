-- Migration 003: Enable RLS policies for tenant isolation (initial example on identity.users)

CREATE SCHEMA IF NOT EXISTS lml;

-- Helper function to read current tenant id safely
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

-- Ensure users table has tenant_id; if not, add for demo (no-op if exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'identity' AND table_name = 'users' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE identity.users ADD COLUMN tenant_id uuid;
  END IF;
END $$;

-- Enable RLS and add basic policies
ALTER TABLE identity.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.users FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='users' AND policyname='users_sel') THEN
    CREATE POLICY users_sel ON identity.users
      FOR SELECT USING (lml.current_tenant() IS NOT NULL AND tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='users' AND policyname='users_ins') THEN
    CREATE POLICY users_ins ON identity.users
      FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='users' AND policyname='users_upd') THEN
    CREATE POLICY users_upd ON identity.users
      FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='users' AND policyname='users_del') THEN
    CREATE POLICY users_del ON identity.users
      FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

-- Journal entry placeholder
INSERT INTO public.schema_migrations (version, checksum)
VALUES ('003', 'PLACEHOLDER_CHECKSUM')
ON CONFLICT (version) DO NOTHING;


