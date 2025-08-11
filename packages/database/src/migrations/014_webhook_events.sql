-- Migration 014: Webhook events deduplication table (payments)

CREATE SCHEMA IF NOT EXISTS payments;
CREATE SCHEMA IF NOT EXISTS lml;
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

CREATE TABLE IF NOT EXISTS payments.webhook_events (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id uuid NOT NULL DEFAULT lml.current_tenant(),
  event_id text NOT NULL,
  provider text NOT NULL DEFAULT 'stripe',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, provider, event_id)
);

ALTER TABLE payments.webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments.webhook_events FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='payments' AND tablename='webhook_events' AND policyname='wh_sel') THEN
    CREATE POLICY wh_sel ON payments.webhook_events FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='payments' AND tablename='webhook_events' AND policyname='wh_ins') THEN
    CREATE POLICY wh_ins ON payments.webhook_events FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('014', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


