-- Migration 005: RLS for inventory, orders, payments tables (scaffold)

CREATE SCHEMA IF NOT EXISTS lml;
CREATE OR REPLACE FUNCTION lml.current_tenant() RETURNS uuid
LANGUAGE SQL STABLE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

-- Inventory tables (example: holds, allocations)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='inventory' AND table_name='holds' AND column_name='tenant_id') THEN
    ALTER TABLE IF EXISTS inventory.holds ADD COLUMN tenant_id uuid;
  END IF;
END $$;

ALTER TABLE IF EXISTS inventory.holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS inventory.holds FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='holds' AND policyname='holds_sel') THEN
    CREATE POLICY holds_sel ON inventory.holds FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='holds' AND policyname='holds_ins') THEN
    CREATE POLICY holds_ins ON inventory.holds FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='holds' AND policyname='holds_upd') THEN
    CREATE POLICY holds_upd ON inventory.holds FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='inventory' AND tablename='holds' AND policyname='holds_del') THEN
    CREATE POLICY holds_del ON inventory.holds FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

-- Orders tables (example)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='orders' AND table_name='orders' AND column_name='tenant_id') THEN
    ALTER TABLE IF EXISTS orders.orders ADD COLUMN tenant_id uuid;
  END IF;
END $$;

ALTER TABLE IF EXISTS orders.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS orders.orders FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='orders' AND tablename='orders' AND policyname='orders_sel') THEN
    CREATE POLICY orders_sel ON orders.orders FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='orders' AND tablename='orders' AND policyname='orders_ins') THEN
    CREATE POLICY orders_ins ON orders.orders FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='orders' AND tablename='orders' AND policyname='orders_upd') THEN
    CREATE POLICY orders_upd ON orders.orders FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='orders' AND tablename='orders' AND policyname='orders_del') THEN
    CREATE POLICY orders_del ON orders.orders FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

-- Payments tables (example)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='payments' AND table_name='payment_intents' AND column_name='tenant_id') THEN
    ALTER TABLE IF EXISTS payments.payment_intents ADD COLUMN tenant_id uuid;
  END IF;
END $$;

ALTER TABLE IF EXISTS payments.payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payments.payment_intents FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='payments' AND tablename='payment_intents' AND policyname='pi_sel') THEN
    CREATE POLICY pi_sel ON payments.payment_intents FOR SELECT USING (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='payments' AND tablename='payment_intents' AND policyname='pi_ins') THEN
    CREATE POLICY pi_ins ON payments.payment_intents FOR INSERT WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='payments' AND tablename='payment_intents' AND policyname='pi_upd') THEN
    CREATE POLICY pi_upd ON payments.payment_intents FOR UPDATE USING (tenant_id = lml.current_tenant()) WITH CHECK (tenant_id = lml.current_tenant());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='payments' AND tablename='payment_intents' AND policyname='pi_del') THEN
    CREATE POLICY pi_del ON payments.payment_intents FOR DELETE USING (tenant_id = lml.current_tenant());
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('005', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


