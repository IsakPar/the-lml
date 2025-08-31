-- Migration 022: Venue Isolation Enhancements
-- Enhances existing tables with venue scoping and creates venue provisioning functions

-- Enhance existing identity.users table with venue scoping
ALTER TABLE identity.users ADD COLUMN IF NOT EXISTS venue_id UUID REFERENCES lml_admin.venue_accounts(id);
ALTER TABLE identity.users ADD COLUMN IF NOT EXISTS lml_admin_role VARCHAR(50) 
    CHECK (lml_admin_role IS NULL OR lml_admin_role IN ('SuperAdmin', 'PlatformAdmin'));
ALTER TABLE identity.users ADD COLUMN IF NOT EXISTS venue_permissions JSONB DEFAULT '{}';

-- Create venue staff management table
CREATE TABLE IF NOT EXISTS identity.venue_staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    
    -- Staff role within the venue
    role VARCHAR(50) NOT NULL CHECK (role IN ('VenueAdmin', 'VenueStaff', 'VenueValidator', 'BoxOffice', 'Security')),
    
    -- Venue-specific permissions
    permissions JSONB NOT NULL DEFAULT '{
        "customers": {
            "read": true,
            "update": false,
            "delete": false
        },
        "shows": {
            "read": true,
            "create": false,
            "update": false,
            "delete": false
        },
        "tickets": {
            "validate": true,
            "refund": false,
            "transfer": false
        },
        "analytics": {
            "read": true,
            "export": false
        },
        "staff": {
            "read": false,
            "invite": false,
            "manage": false
        }
    }',
    
    -- Staff details
    job_title VARCHAR(255),
    department VARCHAR(100),
    employee_id VARCHAR(50),
    
    -- Status and lifecycle
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended', 'terminated')),
    invited_at TIMESTAMP WITH TIME ZONE,
    activated_at TIMESTAMP WITH TIME ZONE,
    last_activity_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES identity.venue_staff(id),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES identity.venue_staff(id),
    
    -- Constraints
    UNIQUE(user_id, venue_id),
    CONSTRAINT venue_staff_job_title_length CHECK (LENGTH(TRIM(job_title)) <= 255),
    CONSTRAINT venue_staff_department_length CHECK (LENGTH(TRIM(department)) <= 100)
);

-- Create venue-specific customer relationship table
CREATE TABLE IF NOT EXISTS identity.venue_customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    
    -- Venue-specific customer data
    venue_customer_id VARCHAR(100), -- Venue's internal customer ID
    customer_notes TEXT,
    preferences JSONB DEFAULT '{}',
    
    -- Customer relationship status
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'banned')),
    vip_status BOOLEAN NOT NULL DEFAULT false,
    
    -- Visit tracking
    first_visit_at TIMESTAMP WITH TIME ZONE,
    last_visit_at TIMESTAMP WITH TIME ZONE,
    total_visits INTEGER NOT NULL DEFAULT 0,
    total_spent DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(customer_id, venue_id),
    CONSTRAINT venue_customer_id_length CHECK (LENGTH(TRIM(venue_customer_id)) <= 100)
);

-- Function to create venue-specific schemas and tables
CREATE OR REPLACE FUNCTION lml_admin.create_venue_schema(
    p_venue_id UUID,
    p_venue_slug TEXT,
    p_created_by UUID
) RETURNS VOID AS $$
DECLARE
    schema_identity TEXT;
    schema_shows TEXT;
    schema_orders TEXT;
    schema_analytics TEXT;
    tables_created JSONB := '{"identity": [], "shows": [], "orders": [], "analytics": []}';
BEGIN
    -- Generate schema names
    schema_identity := 'venue_' || p_venue_slug || '_identity';
    schema_shows := 'venue_' || p_venue_slug || '_shows';
    schema_orders := 'venue_' || p_venue_slug || '_orders';
    schema_analytics := 'venue_' || p_venue_slug || '_analytics';
    
    -- Create venue-specific schemas
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_identity);
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_shows);
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_orders);
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_analytics);
    
    -- Grant schema permissions
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO thankful_app', schema_identity);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO thankful_app', schema_shows);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO thankful_app', schema_orders);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO thankful_app', schema_analytics);
    
    -- Create venue-specific identity tables
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.customer_interactions (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            customer_id UUID NOT NULL REFERENCES identity.users(id),
            venue_id UUID NOT NULL DEFAULT %L,
            interaction_type VARCHAR(100) NOT NULL,
            interaction_data JSONB NOT NULL DEFAULT ''{}''::jsonb,
            staff_id UUID REFERENCES identity.venue_staff(id),
            occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )', schema_identity, p_venue_id);
    
    tables_created := jsonb_set(tables_created, '{identity}', 
        (tables_created->'identity')::jsonb || '["customer_interactions"]'::jsonb);
    
    -- Create venue-specific show tables
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.show_analytics (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            show_id UUID NOT NULL,
            venue_id UUID NOT NULL DEFAULT %L,
            performance_date DATE NOT NULL,
            metrics JSONB NOT NULL DEFAULT ''{}''::jsonb,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )', schema_shows, p_venue_id);
    
    tables_created := jsonb_set(tables_created, '{shows}', 
        (tables_created->'shows')::jsonb || '["show_analytics"]'::jsonb);
    
    -- Create venue-specific order tables  
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.order_analytics (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            order_id UUID NOT NULL,
            venue_id UUID NOT NULL DEFAULT %L,
            order_date DATE NOT NULL,
            analytics_data JSONB NOT NULL DEFAULT ''{}''::jsonb,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )', schema_orders, p_venue_id);
    
    tables_created := jsonb_set(tables_created, '{orders}', 
        (tables_created->'orders')::jsonb || '["order_analytics"]'::jsonb);
    
    -- Create venue-specific analytics tables
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.daily_metrics (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            venue_id UUID NOT NULL DEFAULT %L,
            metric_date DATE NOT NULL,
            metrics JSONB NOT NULL DEFAULT ''{}''::jsonb,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            UNIQUE(venue_id, metric_date)
        )', schema_analytics, p_venue_id);
    
    tables_created := jsonb_set(tables_created, '{analytics}', 
        (tables_created->'analytics')::jsonb || '["daily_metrics"]'::jsonb);
    
    -- Enable RLS on all venue tables
    EXECUTE format('ALTER TABLE %I.customer_interactions ENABLE ROW LEVEL SECURITY', schema_identity);
    EXECUTE format('ALTER TABLE %I.customer_interactions FORCE ROW LEVEL SECURITY', schema_identity);
    EXECUTE format('ALTER TABLE %I.show_analytics ENABLE ROW LEVEL SECURITY', schema_shows);
    EXECUTE format('ALTER TABLE %I.show_analytics FORCE ROW LEVEL SECURITY', schema_shows);
    EXECUTE format('ALTER TABLE %I.order_analytics ENABLE ROW LEVEL SECURITY', schema_orders);
    EXECUTE format('ALTER TABLE %I.order_analytics FORCE ROW LEVEL SECURITY', schema_orders);
    EXECUTE format('ALTER TABLE %I.daily_metrics ENABLE ROW LEVEL SECURITY', schema_analytics);
    EXECUTE format('ALTER TABLE %I.daily_metrics FORCE ROW LEVEL SECURITY', schema_analytics);
    
    -- Create venue-specific RLS policies
    EXECUTE format('
        CREATE POLICY venue_isolation_policy ON %I.customer_interactions
        FOR ALL USING (venue_id = %L)
    ', schema_identity, p_venue_id);
    
    EXECUTE format('
        CREATE POLICY venue_isolation_policy ON %I.show_analytics
        FOR ALL USING (venue_id = %L)
    ', schema_shows, p_venue_id);
    
    EXECUTE format('
        CREATE POLICY venue_isolation_policy ON %I.order_analytics
        FOR ALL USING (venue_id = %L)
    ', schema_orders, p_venue_id);
    
    EXECUTE format('
        CREATE POLICY venue_isolation_policy ON %I.daily_metrics
        FOR ALL USING (venue_id = %L)
    ', schema_analytics, p_venue_id);
    
    -- Grant table permissions
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO thankful_app', schema_identity);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO thankful_app', schema_shows);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO thankful_app', schema_orders);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO thankful_app', schema_analytics);
    
    -- Set default privileges
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES TO thankful_app', schema_identity);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES TO thankful_app', schema_shows);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES TO thankful_app', schema_orders);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES TO thankful_app', schema_analytics);
    
    -- Record schema creation
    INSERT INTO lml_admin.venue_schemas (
        venue_id, 
        schema_prefix, 
        provisioned_by, 
        tables_created,
        table_count
    ) VALUES (
        p_venue_id, 
        p_venue_slug, 
        p_created_by, 
        tables_created,
        4
    );
    
    -- Log the action
    PERFORM lml_admin.log_platform_action(
        p_created_by,
        'PlatformAdmin',
        'create_venue_schema',
        'venue_schema',
        p_venue_slug,
        p_venue_id,
        jsonb_build_object('schemas_created', ARRAY[schema_identity, schema_shows, schema_orders, schema_analytics]),
        true
    );
    
END;
$$ LANGUAGE plpgsql;

-- Function to provision venue admin user
CREATE OR REPLACE FUNCTION lml_admin.provision_venue_admin(
    p_venue_id UUID,
    p_user_id UUID,
    p_created_by UUID
) RETURNS UUID AS $$
DECLARE
    venue_staff_id UUID;
    admin_permissions JSONB;
BEGIN
    -- Define full admin permissions for venue
    admin_permissions := '{
        "customers": {
            "read": true,
            "update": true,
            "delete": true,
            "export": true
        },
        "shows": {
            "read": true,
            "create": true,
            "update": true,
            "delete": true,
            "publish": true
        },
        "tickets": {
            "validate": true,
            "refund": true,
            "transfer": true,
            "comp": true
        },
        "analytics": {
            "read": true,
            "export": true,
            "dashboard": true
        },
        "staff": {
            "read": true,
            "invite": true,
            "manage": true,
            "permissions": true
        },
        "venue": {
            "settings": true,
            "branding": true,
            "configuration": true
        }
    }'::jsonb;
    
    -- Update user with venue association
    UPDATE identity.users 
    SET venue_id = p_venue_id,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Create venue staff record
    INSERT INTO identity.venue_staff (
        user_id,
        venue_id,
        role,
        permissions,
        status,
        job_title,
        activated_at,
        created_by
    ) VALUES (
        p_user_id,
        p_venue_id,
        'VenueAdmin',
        admin_permissions,
        'active',
        'Venue Administrator',
        NOW(),
        p_created_by
    ) RETURNING id INTO venue_staff_id;
    
    -- Log the action
    PERFORM lml_admin.log_platform_action(
        p_created_by,
        'PlatformAdmin',
        'provision_venue_admin',
        'venue_staff',
        venue_staff_id::text,
        p_venue_id,
        jsonb_build_object('user_id', p_user_id, 'role', 'VenueAdmin'),
        true
    );
    
    RETURN venue_staff_id;
END;
$$ LANGUAGE plpgsql;

-- Enhanced venue context function for RLS
CREATE OR REPLACE FUNCTION lml_admin.current_venue_context() RETURNS TABLE(
    venue_id UUID,
    user_id UUID,
    user_role TEXT,
    venue_role TEXT,
    is_lml_admin BOOLEAN
) AS $$
DECLARE
    ctx_venue_id UUID;
    ctx_user_id UUID;
    user_venue_id UUID;
    user_lml_role TEXT;
    user_venue_role TEXT;
    staff_role TEXT;
BEGIN
    -- Get current context from session settings
    BEGIN
        ctx_venue_id := NULLIF(current_setting('app.venue_id', true), '')::uuid;
        ctx_user_id := NULLIF(current_setting('app.user_id', true), '')::uuid;
    EXCEPTION
        WHEN OTHERS THEN
            ctx_venue_id := NULL;
            ctx_user_id := NULL;
    END;
    
    -- Get user details if user_id is available
    IF ctx_user_id IS NOT NULL THEN
        SELECT u.venue_id, u.lml_admin_role, u.role
        INTO user_venue_id, user_lml_role, user_venue_role
        FROM identity.users u
        WHERE u.id = ctx_user_id;
        
        -- Get venue staff role if applicable
        IF ctx_venue_id IS NOT NULL THEN
            SELECT vs.role
            INTO staff_role
            FROM identity.venue_staff vs
            WHERE vs.user_id = ctx_user_id 
            AND vs.venue_id = ctx_venue_id
            AND vs.status = 'active';
        END IF;
    END IF;
    
    RETURN QUERY SELECT 
        COALESCE(ctx_venue_id, user_venue_id),
        ctx_user_id,
        COALESCE(user_venue_role, 'user'),
        COALESCE(staff_role, 'none'),
        (user_lml_role IS NOT NULL AND user_lml_role IN ('SuperAdmin', 'PlatformAdmin'));
END;
$$ LANGUAGE plpgsql STABLE;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_venue_id ON identity.users(venue_id) WHERE venue_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_lml_admin_role ON identity.users(lml_admin_role) WHERE lml_admin_role IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_venue_staff_user_venue ON identity.venue_staff(user_id, venue_id);
CREATE INDEX IF NOT EXISTS idx_venue_staff_venue_role ON identity.venue_staff(venue_id, role);
CREATE INDEX IF NOT EXISTS idx_venue_staff_status ON identity.venue_staff(status) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_venue_customers_venue_customer ON identity.venue_customers(venue_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_venue_customers_status ON identity.venue_customers(venue_id, status);
CREATE INDEX IF NOT EXISTS idx_venue_customers_last_visit ON identity.venue_customers(venue_id, last_visit_at);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE identity.venue_staff TO thankful_app;
GRANT ALL PRIVILEGES ON TABLE identity.venue_customers TO thankful_app;

-- Record migration
INSERT INTO public.schema_migrations (version, checksum)
VALUES ('022', 'venue_isolation_enhancements_v1')
ON CONFLICT (version) DO NOTHING;

