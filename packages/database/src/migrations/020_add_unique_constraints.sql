-- Migration 020: Ensure unique constraints for upserts

-- Unique on venues.venues (tenant_id, name)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'venues_name_unique') THEN
    ALTER TABLE venues.venues
      ADD CONSTRAINT venues_name_unique UNIQUE (tenant_id, name);
  END IF;
END $$;

-- Unique on venues.shows (tenant_id, venue_id, title)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'shows_title_unique') THEN
    ALTER TABLE venues.shows
      ADD CONSTRAINT shows_title_unique UNIQUE (tenant_id, venue_id, title);
  END IF;
END $$;

-- Unique on venues.price_tiers (tenant_id, show_id, code)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'price_tiers_code_unique') THEN
    ALTER TABLE venues.price_tiers
      ADD CONSTRAINT price_tiers_code_unique UNIQUE (tenant_id, show_id, code);
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('020', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


