-- Migration 007: Enforce RLS on identity auxiliary tables (sessions, verification, resets)

CREATE SCHEMA IF NOT EXISTS lml;
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

-- Helper to add tenant_id column if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'identity' AND table_name = 'user_sessions' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE identity.user_sessions ADD COLUMN tenant_id uuid;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'identity' AND table_name = 'email_verification_tokens' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE identity.email_verification_tokens ADD COLUMN tenant_id uuid;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'identity' AND table_name = 'phone_verification_codes' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE identity.phone_verification_codes ADD COLUMN tenant_id uuid;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'identity' AND table_name = 'password_reset_tokens' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE identity.password_reset_tokens ADD COLUMN tenant_id uuid;
  END IF;
END $$;

-- Defaults and NOT NULL (assumes new data; existing rows may need backfill in environments with data)
ALTER TABLE identity.user_sessions ALTER COLUMN tenant_id SET DEFAULT lml.current_tenant();
ALTER TABLE identity.email_verification_tokens ALTER COLUMN tenant_id SET DEFAULT lml.current_tenant();
ALTER TABLE identity.phone_verification_codes ALTER COLUMN tenant_id SET DEFAULT lml.current_tenant();
ALTER TABLE identity.password_reset_tokens ALTER COLUMN tenant_id SET DEFAULT lml.current_tenant();

ALTER TABLE identity.user_sessions ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE identity.email_verification_tokens ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE identity.phone_verification_codes ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE identity.password_reset_tokens ALTER COLUMN tenant_id SET NOT NULL;

-- Enable/force RLS and policies
ALTER TABLE identity.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.user_sessions FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='user_sessions' AND policyname='sess_sel') THEN
    CREATE POLICY sess_sel ON identity.user_sessions FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='user_sessions' AND policyname='sess_ins') THEN
    CREATE POLICY sess_ins ON identity.user_sessions FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='user_sessions' AND policyname='sess_upd') THEN
    CREATE POLICY sess_upd ON identity.user_sessions FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='user_sessions' AND policyname='sess_del') THEN
    CREATE POLICY sess_del ON identity.user_sessions FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

ALTER TABLE identity.email_verification_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.email_verification_tokens FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='email_verification_tokens' AND policyname='evt_sel') THEN
    CREATE POLICY evt_sel ON identity.email_verification_tokens FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='email_verification_tokens' AND policyname='evt_ins') THEN
    CREATE POLICY evt_ins ON identity.email_verification_tokens FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='email_verification_tokens' AND policyname='evt_upd') THEN
    CREATE POLICY evt_upd ON identity.email_verification_tokens FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='email_verification_tokens' AND policyname='evt_del') THEN
    CREATE POLICY evt_del ON identity.email_verification_tokens FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

ALTER TABLE identity.phone_verification_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.phone_verification_codes FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='phone_verification_codes' AND policyname='pvc_sel') THEN
    CREATE POLICY pvc_sel ON identity.phone_verification_codes FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='phone_verification_codes' AND policyname='pvc_ins') THEN
    CREATE POLICY pvc_ins ON identity.phone_verification_codes FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='phone_verification_codes' AND policyname='pvc_upd') THEN
    CREATE POLICY pvc_upd ON identity.phone_verification_codes FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='phone_verification_codes' AND policyname='pvc_del') THEN
    CREATE POLICY pvc_del ON identity.phone_verification_codes FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

ALTER TABLE identity.password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.password_reset_tokens FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='password_reset_tokens' AND policyname='prt_sel') THEN
    CREATE POLICY prt_sel ON identity.password_reset_tokens FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='password_reset_tokens' AND policyname='prt_ins') THEN
    CREATE POLICY prt_ins ON identity.password_reset_tokens FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='password_reset_tokens' AND policyname='prt_upd') THEN
    CREATE POLICY prt_upd ON identity.password_reset_tokens FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='identity' AND tablename='password_reset_tokens' AND policyname='prt_del') THEN
    CREATE POLICY prt_del ON identity.password_reset_tokens FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('007', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


