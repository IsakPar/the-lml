-- Migration 001: Create Schemas and Extensions
-- Creates the foundational database schemas for all bounded contexts

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For full-text search
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For improved JSONB indexing

-- Create schemas for each bounded context
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS venues;
CREATE SCHEMA IF NOT EXISTS ticketing;
CREATE SCHEMA IF NOT EXISTS payments;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS verification;

-- Grant permissions to application user
-- Note: Replace 'thankful_app' with your actual application database user
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'thankful_app') THEN
    GRANT USAGE ON SCHEMA identity TO thankful_app;
    GRANT USAGE ON SCHEMA venues TO thankful_app;
    GRANT USAGE ON SCHEMA ticketing TO thankful_app;
    GRANT USAGE ON SCHEMA payments TO thankful_app;
    GRANT USAGE ON SCHEMA inventory TO thankful_app;
    GRANT USAGE ON SCHEMA verification TO thankful_app;
    
    -- Grant default privileges for future tables
    ALTER DEFAULT PRIVILEGES IN SCHEMA identity GRANT ALL ON TABLES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA venues GRANT ALL ON TABLES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA ticketing GRANT ALL ON TABLES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA payments GRANT ALL ON TABLES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA inventory GRANT ALL ON TABLES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA verification GRANT ALL ON TABLES TO thankful_app;
    
    -- Grant sequence permissions
    ALTER DEFAULT PRIVILEGES IN SCHEMA identity GRANT USAGE ON SEQUENCES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA venues GRANT USAGE ON SEQUENCES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA ticketing GRANT USAGE ON SEQUENCES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA payments GRANT USAGE ON SEQUENCES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA inventory GRANT USAGE ON SEQUENCES TO thankful_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA verification GRANT USAGE ON SEQUENCES TO thankful_app;
  END IF;
END
$$;

-- Create migration tracking table
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version VARCHAR(255) PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  checksum VARCHAR(64) NOT NULL
);

-- Record this migration
INSERT INTO public.schema_migrations (version, checksum) 
VALUES ('001', 'sha256_placeholder_replace_with_actual_hash')
ON CONFLICT (version) DO NOTHING;
