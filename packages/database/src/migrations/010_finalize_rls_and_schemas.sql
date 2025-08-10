-- Migration 010: Finalize schemas and RLS enforcement for Phase 1

-- Ensure missing schemas exist (idempotent)
CREATE SCHEMA IF NOT EXISTS orders;

-- Helper schema/function (idempotent)
CREATE SCHEMA IF NOT EXISTS lml;
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

-- Ensure FORCE RLS remains enforced on core tenant tables (no-ops if already set)
ALTER TABLE IF EXISTS venues.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS venues.venues FORCE ROW LEVEL SECURITY;

ALTER TABLE IF EXISTS inventory.holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS inventory.holds FORCE ROW LEVEL SECURITY;

ALTER TABLE IF EXISTS orders.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS orders.orders FORCE ROW LEVEL SECURITY;

ALTER TABLE IF EXISTS payments.payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payments.payment_intents FORCE ROW LEVEL SECURITY;

-- Record migration
INSERT INTO public.schema_migrations (version, checksum)
VALUES ('010', 'PLACEHOLDER_CHECKSUM')
ON CONFLICT (version) DO NOTHING;


