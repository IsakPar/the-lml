-- Migration 012: Tickets issuance and redemption with RLS

CREATE SCHEMA IF NOT EXISTS ticketing;
CREATE SCHEMA IF NOT EXISTS lml;
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

CREATE TABLE IF NOT EXISTS ticketing.tickets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  order_id UUID NOT NULL,
  performance_id TEXT NOT NULL,
  seat_id TEXT NOT NULL,
  jti TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('issued', 'redeemed', 'revoked')) DEFAULT 'issued',
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  redeemed_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  UNIQUE (tenant_id, jti)
);

CREATE INDEX IF NOT EXISTS idx_tickets_tenant_jti ON ticketing.tickets(tenant_id, jti);
CREATE INDEX IF NOT EXISTS idx_tickets_order ON ticketing.tickets(tenant_id, order_id);

ALTER TABLE ticketing.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticketing.tickets FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='ticketing' AND tablename='tickets' AND policyname='tickets_sel') THEN
    CREATE POLICY tickets_sel ON ticketing.tickets FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='ticketing' AND tablename='tickets' AND policyname='tickets_ins') THEN
    CREATE POLICY tickets_ins ON ticketing.tickets FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='ticketing' AND tablename='tickets' AND policyname='tickets_upd') THEN
    CREATE POLICY tickets_upd ON ticketing.tickets FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='ticketing' AND tablename='tickets' AND policyname='tickets_del') THEN
    CREATE POLICY tickets_del ON ticketing.tickets FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('012', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


