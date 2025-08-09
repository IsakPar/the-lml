// Tables: payment_intents(id uuid pk, tenant_id uuid, order_id uuid fk, provider text, status text, amount_minor bigint, currency char(3), created_at);
// charges(id uuid pk, tenant_id uuid, intent_id uuid fk, status text, provider_ref text, amount_minor bigint, currency char(3), created_at);
// refunds(id uuid pk, tenant_id uuid, charge_id uuid fk, amount_minor bigint, currency char(3), created_at);
// stripe_events(event_id text pk, tenant_id uuid, payload jsonb, created_at);
// Indexes/FKs: uniques on (tenant_id, event_id) where applicable; FKs fk_charges_intent, fk_refunds_charge.
// RLS: enabled on every table with USING/WITH CHECK via current_setting('app.tenant_id').
// Money: minor units int/bigint + currency CHAR(3).
// Stripe events: prefer composite unique on (tenant_id, event_id) to avoid cross-tenant collisions and align with RLS.
