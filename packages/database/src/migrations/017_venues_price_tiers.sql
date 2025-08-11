-- Migration 017: Price tiers per show with RLS

CREATE TABLE IF NOT EXISTS venues.price_tiers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  show_id UUID NOT NULL REFERENCES venues.shows(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  amount_minor BIGINT NOT NULL,
  color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT price_tiers_code_unique UNIQUE (tenant_id, show_id, code)
);

CREATE INDEX IF NOT EXISTS idx_pt_tenant ON venues.price_tiers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_pt_show ON venues.price_tiers(tenant_id, show_id);

ALTER TABLE venues.price_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues.price_tiers FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='price_tiers' AND policyname='pt_sel') THEN
    CREATE POLICY pt_sel ON venues.price_tiers FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='price_tiers' AND policyname='pt_ins') THEN
    CREATE POLICY pt_ins ON venues.price_tiers FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='price_tiers' AND policyname='pt_upd') THEN
    CREATE POLICY pt_upd ON venues.price_tiers FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='price_tiers' AND policyname='pt_del') THEN
    CREATE POLICY pt_del ON venues.price_tiers FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('017', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


