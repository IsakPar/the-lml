-- Migration 021: Create LML Admin Core Schema
-- Creates foundational tables for LML platform administration and venue management

-- Create LML Admin schema for platform-level operations
CREATE SCHEMA IF NOT EXISTS lml_admin;

-- Platform Administrators table (LML employees with platform access)
CREATE TABLE IF NOT EXISTS lml_admin.platform_administrators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL CHECK (role IN ('SuperAdmin', 'PlatformAdmin')),
    permissions JSONB NOT NULL DEFAULT '{
        "venues": {
            "create": true,
            "read": true,
            "update": true,
            "delete": true,
            "suspend": true
        },
        "platform": {
            "analytics": true,
            "billing": true,
            "system_config": true,
            "emergency_access": true
        }
    }',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES lml_admin.platform_administrators(id),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    
    -- Ensure one admin record per user
    UNIQUE(user_id)
);

-- Venue Accounts table (master registry of all venues on platform)
CREATE TABLE IF NOT EXISTS lml_admin.venue_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venue_name VARCHAR(255) NOT NULL,
    venue_slug VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(255) NOT NULL, -- For public-facing display
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended', 'archived')),
    
    -- Venue Configuration
    configuration JSONB NOT NULL DEFAULT '{
        "branding": {
            "logo_url": null,
            "primary_color": "#000000",
            "secondary_color": "#ffffff",
            "theme": "default"
        },
        "features": {
            "ticket_validation": true,
            "customer_management": true,
            "analytics": true,
            "staff_management": true
        },
        "limits": {
            "max_staff": 50,
            "max_shows_per_month": 100,
            "max_customers": 10000
        }
    }',
    
    -- Billing Configuration  
    billing_config JSONB NOT NULL DEFAULT '{
        "plan": "standard",
        "fee_percentage": 2.5,
        "monthly_fee": 99.00,
        "transaction_fee": 0.30,
        "currency": "USD"
    }',
    
    -- Contact Information
    contact_info JSONB NOT NULL DEFAULT '{
        "primary_contact": {
            "name": "",
            "email": "",
            "phone": ""
        },
        "billing_contact": {
            "name": "",
            "email": "",
            "phone": ""
        },
        "technical_contact": {
            "name": "",
            "email": "",
            "phone": ""
        }
    }',
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES lml_admin.platform_administrators(id),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES lml_admin.platform_administrators(id),
    activated_at TIMESTAMP WITH TIME ZONE,
    suspended_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT venue_slug_format CHECK (venue_slug ~ '^[a-z0-9][a-z0-9_-]*[a-z0-9]$'),
    CONSTRAINT venue_name_not_empty CHECK (LENGTH(TRIM(venue_name)) > 0),
    CONSTRAINT display_name_not_empty CHECK (LENGTH(TRIM(display_name)) > 0)
);

-- Venue Schema Registry (tracks dynamically created venue schemas)
CREATE TABLE IF NOT EXISTS lml_admin.venue_schemas (
    venue_id UUID PRIMARY KEY REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    schema_prefix VARCHAR(100) NOT NULL,
    provisioned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    provisioned_by UUID NOT NULL REFERENCES lml_admin.platform_administrators(id),
    
    -- Track created tables and their status
    tables_created JSONB NOT NULL DEFAULT '{
        "identity": [],
        "shows": [],
        "orders": [],
        "analytics": []
    }',
    
    -- Schema health and statistics
    last_health_check TIMESTAMP WITH TIME ZONE,
    table_count INTEGER DEFAULT 0,
    is_healthy BOOLEAN DEFAULT true,
    
    UNIQUE(schema_prefix)
);

-- Platform Billing (track venue usage for billing)
CREATE TABLE IF NOT EXISTS lml_admin.platform_billing (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    
    -- Usage metrics
    usage_metrics JSONB NOT NULL DEFAULT '{
        "transactions": 0,
        "customers": 0,
        "staff_seats": 0,
        "shows": 0,
        "api_calls": 0,
        "storage_gb": 0
    }',
    
    -- Calculated fees
    base_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    transaction_fees DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    overage_fees DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    
    -- Billing status
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'invoiced', 'paid', 'overdue')),
    invoiced_at TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure one billing record per venue per period
    UNIQUE(venue_id, billing_period_start, billing_period_end)
);

-- Platform Audit Log (security and compliance tracking)
CREATE TABLE IF NOT EXISTS lml_admin.platform_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Who performed the action
    actor_id UUID REFERENCES identity.users(id),
    actor_type VARCHAR(50) NOT NULL CHECK (actor_type IN ('PlatformAdmin', 'SuperAdmin', 'VenueAdmin', 'VenueStaff', 'System')),
    
    -- What action was performed
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(255),
    venue_id UUID REFERENCES lml_admin.venue_accounts(id),
    
    -- Action details
    action_details JSONB NOT NULL DEFAULT '{}',
    
    -- Request context
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255),
    correlation_id UUID,
    
    -- Result
    success BOOLEAN NOT NULL,
    error_message TEXT,
    
    -- Timestamp
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Indexes for efficient querying
    CONSTRAINT audit_log_action_not_empty CHECK (LENGTH(TRIM(action)) > 0),
    CONSTRAINT audit_log_resource_type_not_empty CHECK (LENGTH(TRIM(resource_type)) > 0)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_platform_administrators_user_id ON lml_admin.platform_administrators(user_id);
CREATE INDEX IF NOT EXISTS idx_platform_administrators_role ON lml_admin.platform_administrators(role) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_venue_accounts_status ON lml_admin.venue_accounts(status);
CREATE INDEX IF NOT EXISTS idx_venue_accounts_slug ON lml_admin.venue_accounts(venue_slug);
CREATE INDEX IF NOT EXISTS idx_venue_accounts_created_at ON lml_admin.venue_accounts(created_at);

CREATE INDEX IF NOT EXISTS idx_venue_schemas_prefix ON lml_admin.venue_schemas(schema_prefix);
CREATE INDEX IF NOT EXISTS idx_venue_schemas_provisioned_at ON lml_admin.venue_schemas(provisioned_at);

CREATE INDEX IF NOT EXISTS idx_platform_billing_venue_period ON lml_admin.platform_billing(venue_id, billing_period_start);
CREATE INDEX IF NOT EXISTS idx_platform_billing_status ON lml_admin.platform_billing(status);

CREATE INDEX IF NOT EXISTS idx_platform_audit_log_actor ON lml_admin.platform_audit_log(actor_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_platform_audit_log_venue ON lml_admin.platform_audit_log(venue_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_platform_audit_log_action ON lml_admin.platform_audit_log(action, occurred_at);
CREATE INDEX IF NOT EXISTS idx_platform_audit_log_resource ON lml_admin.platform_audit_log(resource_type, resource_id);

-- Grant permissions to application user
GRANT USAGE ON SCHEMA lml_admin TO thankful_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA lml_admin TO thankful_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA lml_admin TO thankful_app;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA lml_admin GRANT ALL ON TABLES TO thankful_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA lml_admin GRANT ALL ON SEQUENCES TO thankful_app;

-- Helper function to log platform actions
CREATE OR REPLACE FUNCTION lml_admin.log_platform_action(
    p_actor_id UUID,
    p_actor_type VARCHAR(50),
    p_action VARCHAR(100),
    p_resource_type VARCHAR(100),
    p_resource_id VARCHAR(255) DEFAULT NULL,
    p_venue_id UUID DEFAULT NULL,
    p_action_details JSONB DEFAULT '{}',
    p_success BOOLEAN DEFAULT true,
    p_error_message TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    audit_id UUID;
    current_correlation_id UUID;
BEGIN
    -- Get correlation ID from current context
    BEGIN
        current_correlation_id := NULLIF(current_setting('app.correlation_id', true), '')::uuid;
    EXCEPTION
        WHEN OTHERS THEN
            current_correlation_id := NULL;
    END;
    
    INSERT INTO lml_admin.platform_audit_log (
        actor_id, actor_type, action, resource_type, resource_id, venue_id,
        action_details, success, error_message, correlation_id
    ) VALUES (
        p_actor_id, p_actor_type, p_action, p_resource_type, p_resource_id, p_venue_id,
        p_action_details, p_success, p_error_message, current_correlation_id
    ) RETURNING id INTO audit_id;
    
    RETURN audit_id;
END;
$$ LANGUAGE plpgsql;

-- Record migration
INSERT INTO public.schema_migrations (version, checksum)
VALUES ('021', 'lml_admin_core_schema_v1')
ON CONFLICT (version) DO NOTHING;

