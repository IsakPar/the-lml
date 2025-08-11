-- Migration 019: Materialized seats per performance + state + history

CREATE TYPE inventory.seat_state_enum AS ENUM ('available','held','reserved','sold','blocked');

-- Catalog of seats per performance (derived from seatmap)
CREATE TABLE IF NOT EXISTS inventory.seat_catalog (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  performance_id UUID NOT NULL,
  seat_id TEXT NOT NULL,
  section TEXT,
  row TEXT,
  number TEXT,
  price_tier_code TEXT,
  color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT seat_catalog_unique UNIQUE (tenant_id, performance_id, seat_id)
);

CREATE INDEX IF NOT EXISTS idx_sc_tenant ON inventory.seat_catalog(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sc_perf ON inventory.seat_catalog(tenant_id, performance_id);

ALTER TABLE inventory.seat_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory.seat_catalog FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_catalog' AND policyname='sc_sel') THEN
    CREATE POLICY sc_sel ON inventory.seat_catalog FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_catalog' AND policyname='sc_ins') THEN
    CREATE POLICY sc_ins ON inventory.seat_catalog FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_catalog' AND policyname='sc_upd') THEN
    CREATE POLICY sc_upd ON inventory.seat_catalog FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_catalog' AND policyname='sc_del') THEN
    CREATE POLICY sc_del ON inventory.seat_catalog FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

-- Current seat state
CREATE TABLE IF NOT EXISTS inventory.seat_state (
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  performance_id UUID NOT NULL,
  seat_id TEXT NOT NULL,
  state inventory.seat_state_enum NOT NULL DEFAULT 'available',
  version BIGINT NOT NULL DEFAULT 1,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (tenant_id, performance_id, seat_id)
);

CREATE INDEX IF NOT EXISTS idx_ss_perf ON inventory.seat_state(tenant_id, performance_id, state);

ALTER TABLE inventory.seat_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory.seat_state FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_state' AND policyname='ss_sel') THEN
    CREATE POLICY ss_sel ON inventory.seat_state FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_state' AND policyname='ss_ins') THEN
    CREATE POLICY ss_ins ON inventory.seat_state FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_state' AND policyname='ss_upd') THEN
    CREATE POLICY ss_upd ON inventory.seat_state FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='seat_state' AND policyname='ss_del') THEN
    CREATE POLICY ss_del ON inventory.seat_state FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

-- History
CREATE TABLE IF NOT EXISTS inventory.seat_state_history (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL,
  performance_id UUID NOT NULL,
  seat_id TEXT NOT NULL,
  prev_state inventory.seat_state_enum,
  next_state inventory.seat_state_enum,
  version BIGINT NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_ssh_perf ON inventory.seat_state_history(tenant_id, performance_id, seat_id, changed_at DESC);

INSERT INTO public.schema_migrations (version, checksum) VALUES ('019', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


