-- Migration 013: Grant ticketing schema privileges to thankful_app for tests

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'thankful_app') THEN
    GRANT USAGE ON SCHEMA ticketing TO thankful_app;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'thankful_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ticketing TO thankful_app';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'thankful_app') THEN
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA ticketing GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO thankful_app';
  END IF;
END $$;

INSERT INTO public.schema_migrations (version, checksum) VALUES ('013', 'PLACEHOLDER_CHECKSUM') ON CONFLICT (version) DO NOTHING;


