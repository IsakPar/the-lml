-- Migration 009: Create core domain tables with tenant-bound RLS

-- Prereqs: schemas created (001), identity tables (002), lml.current_tenant() declared (003)

-- Generic trigger function for updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- VENUES ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS venues.venues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  name TEXT NOT NULL,
  tz TEXT NOT NULL DEFAULT 'UTC',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT venues_name_unique UNIQUE (tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_venues_tenant ON venues.venues(tenant_id);

DROP TRIGGER IF EXISTS trg_venues_updated_at ON venues.venues;
CREATE TRIGGER trg_venues_updated_at
  BEFORE UPDATE ON venues.venues
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE venues.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues.venues FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
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

-- INVENTORY ------------------------------------------------------------------
-- Minimal holds table for RLS; adapt as inventory grows
CREATE TABLE IF NOT EXISTS inventory.holds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  performance_id TEXT NOT NULL,
  seat_id TEXT NOT NULL,
  hold_token TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT holds_seat_uniq UNIQUE (tenant_id, performance_id, seat_id)
);

CREATE INDEX IF NOT EXISTS idx_holds_tenant ON inventory.holds(tenant_id);
CREATE INDEX IF NOT EXISTS idx_holds_perf ON inventory.holds(tenant_id, performance_id);

ALTER TABLE inventory.holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory.holds FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
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

-- ORDERS ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders.orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  customer_id UUID,
  status TEXT NOT NULL CHECK (status IN ('pending','awaiting_payment','paid','cancelled','void','refunded')),
  total_minor BIGINT NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_tenant ON orders.orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders.orders(tenant_id, status);

DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders.orders;
CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON orders.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE orders.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders.orders FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
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

-- PAYMENTS -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments.payment_intents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL DEFAULT lml.current_tenant(),
  order_id UUID REFERENCES orders.orders(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'stripe',
  status TEXT NOT NULL CHECK (status IN ('requires_payment_method','requires_action','processing','succeeded','canceled','failed')),
  amount_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  client_secret_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pi_tenant ON payments.payment_intents(tenant_id);
CREATE INDEX IF NOT EXISTS idx_pi_order ON payments.payment_intents(tenant_id, order_id);

DROP TRIGGER IF EXISTS trg_pi_updated_at ON payments.payment_intents;
CREATE TRIGGER trg_pi_updated_at
  BEFORE UPDATE ON payments.payment_intents
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE payments.payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments.payment_intents FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
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

-- Journal
INSERT INTO public.schema_migrations (version, checksum) VALUES ('009', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


