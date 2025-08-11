-- Migration 016: Venues performances table with RLS

CREATE TYPE venues.performance_status AS ENUM ('scheduled','cancelled');

CREATE TABLE IF NOT EXISTS venues.performances (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  show_id UUID NOT NULL REFERENCES venues.shows(id) ON DELETE CASCADE,
  starts_at TIMESTAMPTZ NOT NULL,
  status venues.performance_status NOT NULL DEFAULT 'scheduled',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_perf_tenant ON venues.performances(tenant_id);
CREATE INDEX IF NOT EXISTS idx_perf_show ON venues.performances(tenant_id, show_id, starts_at);

ALTER TABLE venues.performances ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues.performances FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='performances' AND policyname='perf_sel') THEN
    CREATE POLICY perf_sel ON venues.performances FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='performances' AND policyname='perf_ins') THEN
    CREATE POLICY perf_ins ON venues.performances FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='performances' AND policyname='perf_upd') THEN
    CREATE POLICY perf_upd ON venues.performances FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='performances' AND policyname='perf_del') THEN
    CREATE POLICY perf_del ON venues.performances FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('016', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


