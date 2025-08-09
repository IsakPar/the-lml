-- Migration 004: Extend RLS to additional tenant tables (venues, inventory placeholders)

CREATE SCHEMA IF NOT EXISTS lml;

-- Ensure helper exists
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

-- Venues table example
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='venues' AND table_name='venues' AND column_name='tenant_id'
  ) THEN
    -- If your schema uses orgId elsewhere, adapt to tenant_id or create a view; this is a placeholder
    ALTER TABLE IF EXISTS venues.venues ADD COLUMN tenant_id uuid;
  END IF;
END $$;

ALTER TABLE IF EXISTS venues.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS venues.venues FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='venues' AND policyname='venues_sel') THEN
    CREATE POLICY venues_sel ON venues.venues FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='venues' AND policyname='venues_ins') THEN
    CREATE POLICY venues_ins ON venues.venues FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='venues' AND policyname='venues_upd') THEN
    CREATE POLICY venues_upd ON venues.venues FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='venues' AND policyname='venues_del') THEN
    CREATE POLICY venues_del ON venues.venues FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('004', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


