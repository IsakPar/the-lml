-- Migration 023: Venue-Scoped Ticket Validation System
-- Creates venue-isolated ticket validation, QR code system, and validation tracking

-- Create venue validation schema for validation-specific operations
CREATE SCHEMA IF NOT EXISTS venue_validation;

-- Venue-scoped QR Code configuration and management
CREATE TABLE IF NOT EXISTS venue_validation.qr_code_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    
    -- QR Code signing configuration (venue-specific keys)
    signing_key_id VARCHAR(255) NOT NULL,
    public_key TEXT NOT NULL,
    private_key_encrypted TEXT NOT NULL, -- Encrypted with venue-specific passphrase
    key_algorithm VARCHAR(50) NOT NULL DEFAULT 'RS256',
    
    -- QR Code format configuration
    qr_format_version INTEGER NOT NULL DEFAULT 1,
    qr_data_structure JSONB NOT NULL DEFAULT '{
        "version": 1,
        "venue_id": null,
        "ticket_id": null,
        "show_id": null,
        "seat_info": null,
        "issue_timestamp": null,
        "expires_at": null,
        "signature": null
    }',
    
    -- Validation rules
    max_scan_attempts INTEGER NOT NULL DEFAULT 3,
    validation_window_hours INTEGER NOT NULL DEFAULT 2,
    allow_early_validation_hours INTEGER NOT NULL DEFAULT 1,
    
    -- Status and lifecycle
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'rotated', 'revoked')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    activated_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    created_by UUID NOT NULL REFERENCES identity.venue_staff(id),
    
    -- Ensure one active config per venue
    UNIQUE(venue_id, status) DEFERRABLE INITIALLY DEFERRED
);

-- Venue-specific ticket validation events
CREATE TABLE IF NOT EXISTS venue_validation.validation_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    
    -- Ticket and validation details
    ticket_id UUID NOT NULL,
    qr_code_data TEXT NOT NULL,
    qr_code_signature TEXT,
    
    -- Show and seat information (from QR code)
    show_id UUID,
    performance_datetime TIMESTAMP WITH TIME ZONE,
    seat_section VARCHAR(100),
    seat_row VARCHAR(10),
    seat_number VARCHAR(10),
    
    -- Validation attempt details
    validation_status VARCHAR(50) NOT NULL CHECK (validation_status IN (
        'valid', 'invalid_signature', 'expired', 'already_used', 
        'wrong_venue', 'wrong_show', 'wrong_time', 'invalid_format',
        'fraud_detected', 'system_error'
    )),
    
    -- Staff and device information
    validated_by UUID REFERENCES identity.venue_staff(id),
    validator_device_id VARCHAR(255),
    validator_device_info JSONB DEFAULT '{}',
    validation_location JSONB DEFAULT '{}', -- GPS, venue zone, etc.
    
    -- Security and fraud detection
    fraud_indicators JSONB DEFAULT '{}',
    security_flags JSONB DEFAULT '{}',
    duplicate_scan_count INTEGER DEFAULT 0,
    
    -- Timing information
    attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Additional validation context
    validation_context JSONB DEFAULT '{}'
);

-- Venue validation statistics and monitoring
CREATE TABLE IF NOT EXISTS venue_validation.validation_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    
    -- Time period for stats
    stats_date DATE NOT NULL,
    stats_hour INTEGER CHECK (stats_hour >= 0 AND stats_hour <= 23),
    
    -- Validation metrics
    total_validations INTEGER NOT NULL DEFAULT 0,
    successful_validations INTEGER NOT NULL DEFAULT 0,
    failed_validations INTEGER NOT NULL DEFAULT 0,
    fraud_attempts INTEGER NOT NULL DEFAULT 0,
    duplicate_attempts INTEGER NOT NULL DEFAULT 0,
    
    -- Performance metrics
    avg_validation_time_ms INTEGER,
    max_validation_time_ms INTEGER,
    min_validation_time_ms INTEGER,
    
    -- Staff activity
    active_validators INTEGER NOT NULL DEFAULT 0,
    validator_stats JSONB DEFAULT '{}',
    
    -- Show breakdown
    show_stats JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Unique constraint for time periods
    UNIQUE(venue_id, stats_date, stats_hour)
);

-- Venue-specific validation devices and access control
CREATE TABLE IF NOT EXISTS venue_validation.validation_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    
    -- Device identification
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    device_type VARCHAR(100) NOT NULL DEFAULT 'mobile', -- mobile, tablet, scanner, kiosk
    
    -- Device assignment and access
    assigned_to UUID REFERENCES identity.venue_staff(id),
    access_zones JSONB DEFAULT '[]', -- Which venue areas this device can validate for
    allowed_show_types JSONB DEFAULT '[]', -- Which show types this device can validate
    
    -- Device configuration
    validation_settings JSONB DEFAULT '{
        "require_staff_pin": true,
        "allow_offline_validation": false,
        "max_offline_validations": 10,
        "require_location_check": true,
        "enable_fraud_detection": true
    }',
    
    -- Device status and health
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended', 'retired')),
    last_seen_at TIMESTAMP WITH TIME ZONE,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    firmware_version VARCHAR(100),
    app_version VARCHAR(100),
    
    -- Security
    device_certificate TEXT,
    last_security_check TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES identity.venue_staff(id),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    UNIQUE(venue_id, device_id)
);

-- Venue validation rules and policies
CREATE TABLE IF NOT EXISTS venue_validation.venue_validation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venue_id UUID NOT NULL REFERENCES lml_admin.venue_accounts(id) ON DELETE CASCADE,
    
    -- Rule identification
    rule_name VARCHAR(255) NOT NULL,
    rule_type VARCHAR(100) NOT NULL, -- time_window, location, staff_role, show_type, etc.
    
    -- Rule configuration
    rule_config JSONB NOT NULL DEFAULT '{}',
    
    -- Rule conditions and actions
    conditions JSONB NOT NULL DEFAULT '{}',
    actions JSONB NOT NULL DEFAULT '{}',
    
    -- Rule priority and status
    priority INTEGER NOT NULL DEFAULT 100,
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Effectiveness tracking
    times_triggered INTEGER NOT NULL DEFAULT 0,
    last_triggered_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES identity.venue_staff(id),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    UNIQUE(venue_id, rule_name)
);

-- Function to validate venue-scoped QR codes
CREATE OR REPLACE FUNCTION venue_validation.validate_venue_qr_code(
    p_venue_id UUID,
    p_qr_code_data TEXT,
    p_validator_id UUID,
    p_device_id VARCHAR(255),
    p_validation_context JSONB DEFAULT '{}'
) RETURNS TABLE (
    validation_id UUID,
    is_valid BOOLEAN,
    validation_status TEXT,
    ticket_info JSONB,
    error_message TEXT
) AS $$
DECLARE
    validation_id UUID;
    qr_data JSONB;
    qr_venue_id UUID;
    ticket_id UUID;
    show_id UUID;
    validation_result VARCHAR(50);
    error_msg TEXT := NULL;
    ticket_details JSONB := '{}';
    validation_config RECORD;
BEGIN
    -- Generate validation ID
    validation_id := uuid_generate_v4();
    
    -- Parse QR code data
    BEGIN
        qr_data := p_qr_code_data::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            validation_result := 'invalid_format';
            error_msg := 'Invalid QR code format';
    END;
    
    -- Validate basic structure if parsing succeeded
    IF validation_result IS NULL THEN
        -- Extract venue ID from QR code
        qr_venue_id := (qr_data->>'venue_id')::uuid;
        
        -- Check venue boundary
        IF qr_venue_id != p_venue_id THEN
            validation_result := 'wrong_venue';
            error_msg := 'QR code belongs to different venue';
        ELSE
            -- Extract ticket and show info
            ticket_id := (qr_data->>'ticket_id')::uuid;
            show_id := (qr_data->>'show_id')::uuid;
            
            -- Get validation configuration for venue
            SELECT * INTO validation_config
            FROM venue_validation.qr_code_configurations
            WHERE venue_id = p_venue_id AND status = 'active'
            LIMIT 1;
            
            IF validation_config IS NULL THEN
                validation_result := 'system_error';
                error_msg := 'No active validation configuration for venue';
            ELSE
                -- Check if ticket has been scanned before
                IF EXISTS (
                    SELECT 1 FROM venue_validation.validation_events
                    WHERE venue_id = p_venue_id 
                    AND ticket_id = ticket_id 
                    AND validation_status = 'valid'
                ) THEN
                    validation_result := 'already_used';
                    error_msg := 'Ticket has already been validated';
                ELSE
                    -- Perform additional validation checks here
                    -- (timing, signature verification, etc.)
                    validation_result := 'valid';
                    ticket_details := jsonb_build_object(
                        'ticket_id', ticket_id,
                        'show_id', show_id,
                        'venue_id', qr_venue_id
                    );
                END IF;
            END IF;
        END IF;
    END IF;
    
    -- Record validation event
    INSERT INTO venue_validation.validation_events (
        id,
        venue_id,
        ticket_id,
        qr_code_data,
        show_id,
        validation_status,
        validated_by,
        validator_device_id,
        validation_context
    ) VALUES (
        validation_id,
        p_venue_id,
        ticket_id,
        p_qr_code_data,
        show_id,
        validation_result,
        p_validator_id,
        p_device_id,
        p_validation_context
    );
    
    -- Return validation result
    RETURN QUERY SELECT 
        validation_id,
        (validation_result = 'valid'),
        validation_result,
        ticket_details,
        error_msg;
END;
$$ LANGUAGE plpgsql;

-- Function to update venue validation statistics
CREATE OR REPLACE FUNCTION venue_validation.update_validation_stats(
    p_venue_id UUID,
    p_stats_date DATE DEFAULT CURRENT_DATE,
    p_stats_hour INTEGER DEFAULT EXTRACT(hour FROM NOW())
) RETURNS VOID AS $$
DECLARE
    stats_record RECORD;
    validation_metrics RECORD;
BEGIN
    -- Calculate metrics for the time period
    SELECT 
        COUNT(*) as total_validations,
        COUNT(*) FILTER (WHERE validation_status = 'valid') as successful_validations,
        COUNT(*) FILTER (WHERE validation_status != 'valid') as failed_validations,
        COUNT(*) FILTER (WHERE validation_status = 'fraud_detected') as fraud_attempts,
        COUNT(*) FILTER (WHERE duplicate_scan_count > 0) as duplicate_attempts,
        COUNT(DISTINCT validated_by) as active_validators
    INTO validation_metrics
    FROM venue_validation.validation_events
    WHERE venue_id = p_venue_id
    AND DATE(attempted_at) = p_stats_date
    AND EXTRACT(hour FROM attempted_at) = p_stats_hour;
    
    -- Upsert statistics record
    INSERT INTO venue_validation.validation_stats (
        venue_id,
        stats_date,
        stats_hour,
        total_validations,
        successful_validations,
        failed_validations,
        fraud_attempts,
        duplicate_attempts,
        active_validators,
        updated_at
    ) VALUES (
        p_venue_id,
        p_stats_date,
        p_stats_hour,
        validation_metrics.total_validations,
        validation_metrics.successful_validations,
        validation_metrics.failed_validations,
        validation_metrics.fraud_attempts,
        validation_metrics.duplicate_attempts,
        validation_metrics.active_validators,
        NOW()
    )
    ON CONFLICT (venue_id, stats_date, stats_hour)
    DO UPDATE SET
        total_validations = EXCLUDED.total_validations,
        successful_validations = EXCLUDED.successful_validations,
        failed_validations = EXCLUDED.failed_validations,
        fraud_attempts = EXCLUDED.fraud_attempts,
        duplicate_attempts = EXCLUDED.duplicate_attempts,
        active_validators = EXCLUDED.active_validators,
        updated_at = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_qr_code_configurations_venue_status ON venue_validation.qr_code_configurations(venue_id, status);

-- Avoid non-IMMUTABLE functions in index expressions; index the timestamp column directly
CREATE INDEX IF NOT EXISTS idx_validation_events_venue_attempted_at ON venue_validation.validation_events(venue_id, attempted_at);
CREATE INDEX IF NOT EXISTS idx_validation_events_ticket ON venue_validation.validation_events(venue_id, ticket_id);
CREATE INDEX IF NOT EXISTS idx_validation_events_validator ON venue_validation.validation_events(validated_by, attempted_at);
CREATE INDEX IF NOT EXISTS idx_validation_events_status ON venue_validation.validation_events(venue_id, validation_status);

CREATE INDEX IF NOT EXISTS idx_validation_stats_venue_period ON venue_validation.validation_stats(venue_id, stats_date, stats_hour);

CREATE INDEX IF NOT EXISTS idx_validation_devices_venue_status ON venue_validation.validation_devices(venue_id, status);
CREATE INDEX IF NOT EXISTS idx_validation_devices_assigned ON venue_validation.validation_devices(assigned_to, status);

CREATE INDEX IF NOT EXISTS idx_venue_validation_rules_venue_active ON venue_validation.venue_validation_rules(venue_id, is_active);

-- Enable RLS on validation tables
ALTER TABLE venue_validation.qr_code_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_validation.qr_code_configurations FORCE ROW LEVEL SECURITY;

ALTER TABLE venue_validation.validation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_validation.validation_events FORCE ROW LEVEL SECURITY;

ALTER TABLE venue_validation.validation_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_validation.validation_stats FORCE ROW LEVEL SECURITY;

ALTER TABLE venue_validation.validation_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_validation.validation_devices FORCE ROW LEVEL SECURITY;

ALTER TABLE venue_validation.venue_validation_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE venue_validation.venue_validation_rules FORCE ROW LEVEL SECURITY;

-- Create venue isolation RLS policies for all tables
CREATE POLICY venue_isolation_qr_config ON venue_validation.qr_code_configurations
    FOR ALL USING (
        venue_id IN (
            SELECT venue_id FROM lml_admin.current_venue_context() 
            WHERE venue_id IS NOT NULL
        )
    );

CREATE POLICY venue_isolation_validation_events ON venue_validation.validation_events
    FOR ALL USING (
        venue_id IN (
            SELECT venue_id FROM lml_admin.current_venue_context() 
            WHERE venue_id IS NOT NULL
        )
    );

CREATE POLICY venue_isolation_validation_stats ON venue_validation.validation_stats
    FOR ALL USING (
        venue_id IN (
            SELECT venue_id FROM lml_admin.current_venue_context() 
            WHERE venue_id IS NOT NULL
        )
    );

CREATE POLICY venue_isolation_validation_devices ON venue_validation.validation_devices
    FOR ALL USING (
        venue_id IN (
            SELECT venue_id FROM lml_admin.current_venue_context() 
            WHERE venue_id IS NOT NULL
        )
    );

CREATE POLICY venue_isolation_validation_rules ON venue_validation.venue_validation_rules
    FOR ALL USING (
        venue_id IN (
            SELECT venue_id FROM lml_admin.current_venue_context() 
            WHERE venue_id IS NOT NULL
        )
    );

-- Grant permissions
GRANT USAGE ON SCHEMA venue_validation TO thankful_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA venue_validation TO thankful_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA venue_validation TO thankful_app;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA venue_validation TO thankful_app;

-- Set default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA venue_validation GRANT ALL ON TABLES TO thankful_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA venue_validation GRANT ALL ON SEQUENCES TO thankful_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA venue_validation GRANT ALL ON FUNCTIONS TO thankful_app;

-- Record migration
INSERT INTO public.schema_migrations (version, checksum)
VALUES ('023', 'venue_ticket_validation_v1')
ON CONFLICT (version) DO NOTHING;

