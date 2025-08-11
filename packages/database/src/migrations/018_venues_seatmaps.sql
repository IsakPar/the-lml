-- Migration 018: Link shows/performances to Mongo seatmaps, with RLS

CREATE TABLE IF NOT EXISTS venues.seatmaps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  show_id UUID NOT NULL REFERENCES venues.shows(id) ON DELETE CASCADE,
  performance_id UUID REFERENCES venues.performances(id) ON DELETE CASCADE,
  seatmap_mongo_id TEXT NOT NULL,
  version INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vseatmaps_tenant ON venues.seatmaps(tenant_id);
CREATE INDEX IF NOT EXISTS idx_vseatmaps_show ON venues.seatmaps(tenant_id, show_id);
CREATE INDEX IF NOT EXISTS idx_vseatmaps_perf ON venues.seatmaps(tenant_id, performance_id);

ALTER TABLE venues.seatmaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues.seatmaps FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='seatmaps' AND policyname='vsm_sel') THEN
    CREATE POLICY vsm_sel ON venues.seatmaps FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='seatmaps' AND policyname='vsm_ins') THEN
    CREATE POLICY vsm_ins ON venues.seatmaps FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='seatmaps' AND policyname='vsm_upd') THEN
    CREATE POLICY vsm_upd ON venues.seatmaps FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='seatmaps' AND policyname='vsm_del') THEN
    CREATE POLICY vsm_del ON venues.seatmaps FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('018', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


