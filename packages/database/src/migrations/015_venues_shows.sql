-- Migration 015: Venues shows table with RLS

-- Shows ----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS venues.shows (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  venue_id UUID NOT NULL REFERENCES venues.venues(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  poster_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT shows_title_unique UNIQUE (tenant_id, venue_id, title)
);

CREATE INDEX IF NOT EXISTS idx_shows_tenant ON venues.shows(tenant_id);
CREATE INDEX IF NOT EXISTS idx_shows_venue ON venues.shows(tenant_id, venue_id);

DROP TRIGGER IF EXISTS trg_shows_updated_at ON venues.shows;
CREATE TRIGGER trg_shows_updated_at
  BEFORE UPDATE ON venues.shows
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE venues.shows ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues.shows FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='shows' AND policyname='shows_sel') THEN
    CREATE POLICY shows_sel ON venues.shows FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='shows' AND policyname='shows_ins') THEN
    CREATE POLICY shows_ins ON venues.shows FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='shows' AND policyname='shows_upd') THEN
    CREATE POLICY shows_upd ON venues.shows FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='venues' AND tablename='shows' AND policyname='shows_del') THEN
    CREATE POLICY shows_del ON venues.shows FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('015', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


