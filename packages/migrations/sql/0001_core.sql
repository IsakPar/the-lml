-- events (shows)
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL,
  layout_id TEXT NOT NULL,
  name TEXT NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL,
  tenant_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- per-event seat inventory
CREATE TABLE IF NOT EXISTS event_seats (
  event_id UUID NOT NULL,
  seat_id  UUID NOT NULL,
  status   TEXT NOT NULL DEFAULT 'AVAILABLE',
  order_id UUID,
  version  BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (event_id, seat_id)
);

CREATE INDEX IF NOT EXISTS idx_event_seats_event_status ON event_seats(event_id, status);
CREATE INDEX IF NOT EXISTS idx_event_seats_order ON event_seats(order_id);

-- orders
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  event_id UUID NOT NULL REFERENCES events(id),
  status TEXT NOT NULL,
  payment_intent_id TEXT UNIQUE,
  total_amount BIGINT NOT NULL,
  currency CHAR(3) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- lines
CREATE TABLE IF NOT EXISTS order_lines (
  id UUID PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  seat_id  UUID NOT NULL,
  price    BIGINT NOT NULL,
  status   TEXT NOT NULL,
  UNIQUE(order_id, seat_id)
);

-- stripe outbox (durable webhook store)
CREATE TABLE IF NOT EXISTS stripe_events (
  event_id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  payment_intent_id TEXT,
  payload JSONB,
  processed BOOLEAN NOT NULL DEFAULT FALSE,
  attempts INT NOT NULL DEFAULT 0,
  last_error TEXT,
  next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- audit
CREATE TABLE IF NOT EXISTS order_audit_log (
  id BIGSERIAL PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  from_status TEXT,
  to_status   TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- helpful constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_payment_intent_unique'
  ) THEN
    ALTER TABLE orders
      ADD CONSTRAINT orders_payment_intent_unique UNIQUE (payment_intent_id);
  END IF;
END
$$;


