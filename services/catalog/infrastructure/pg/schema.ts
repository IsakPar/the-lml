// Tables: venues(id uuid pk, tenant_id uuid, name text, address text, created_at, updated_at);
// performances(id uuid pk, tenant_id uuid, event_id uuid, venue_id uuid fk, starts_at timestamptz, seatmap_version int, created_at);
// seatmap_refs(id uuid pk, tenant_id uuid, venue_id uuid fk, version int, unique(tenant_id, venue_id, version));
// Indexes/FKs: (tenant_id,venue_id,version) unique; FK names fk_perf_venue, fk_ref_venue.
// RLS: enabled on every table with USING/WITH CHECK via current_setting('app.tenant_id').
// Money: minor units int/bigint + currency CHAR(3).
