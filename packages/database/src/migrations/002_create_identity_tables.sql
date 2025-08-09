-- Migration 002: Create Identity Context Tables
-- Creates tables for user management, authentication, and sessions

-- Create identity schema if not exists
CREATE SCHEMA IF NOT EXISTS identity;

-- Users table with comprehensive profile support
CREATE TABLE identity.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email CITEXT UNIQUE NOT NULL,
  phone VARCHAR(20),
  password_hash VARCHAR(255),
  role VARCHAR(50) NOT NULL DEFAULT 'user',
  is_email_verified BOOLEAN NOT NULL DEFAULT false,
  is_phone_verified BOOLEAN NOT NULL DEFAULT false,
  
  -- Profile information
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  date_of_birth DATE,
  avatar_url TEXT,
  
  -- Preferences (JSON for flexibility)
  preferences JSONB NOT NULL DEFAULT '{
    "notifications": {
      "email": true,
      "sms": true,
      "push": true
    },
    "timezone": "UTC",
    "language": "en"
  }',
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMP WITH TIME ZONE,
  
  -- Constraints
  CONSTRAINT users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT users_role_valid CHECK (role IN ('user', 'organizer_admin', 'support', 'super_admin')),
  CONSTRAINT users_name_not_empty CHECK (first_name != '' AND last_name != '')
);

-- User sessions with device tracking
CREATE TABLE identity.user_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  device_id VARCHAR(255),
  device_type VARCHAR(50), -- 'mobile', 'web', 'tablet'
  device_name TEXT,
  ip_address INET,
  user_agent TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  last_accessed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Security constraints
  CONSTRAINT sessions_expires_future CHECK (expires_at > created_at)
);

-- Email verification tokens
CREATE TABLE identity.email_verification_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  used_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT verification_expires_future CHECK (expires_at > created_at)
);

-- Phone verification codes
CREATE TABLE identity.phone_verification_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  phone VARCHAR(20) NOT NULL,
  code_hash VARCHAR(255) NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  verified_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT phone_verification_max_attempts CHECK (attempts <= 5),
  CONSTRAINT phone_verification_expires_future CHECK (expires_at > created_at)
);

-- Password reset tokens
CREATE TABLE identity.password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  used_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT reset_expires_future CHECK (expires_at > created_at)
);

-- Indexes for performance
CREATE INDEX idx_users_email ON identity.users(email);
CREATE INDEX idx_users_phone ON identity.users(phone);
CREATE INDEX idx_users_role ON identity.users(role);
CREATE INDEX idx_users_created_at ON identity.users(created_at);

CREATE INDEX idx_sessions_user_id ON identity.user_sessions(user_id);
CREATE INDEX idx_sessions_token_hash ON identity.user_sessions(token_hash);
CREATE INDEX idx_sessions_device_id ON identity.user_sessions(device_id);
CREATE INDEX idx_sessions_expires_at ON identity.user_sessions(expires_at);
CREATE INDEX idx_sessions_active ON identity.user_sessions(is_active);

CREATE INDEX idx_email_verification_user_id ON identity.email_verification_tokens(user_id);
CREATE INDEX idx_email_verification_token ON identity.email_verification_tokens(token_hash);

CREATE INDEX idx_phone_verification_user_id ON identity.phone_verification_codes(user_id);
CREATE INDEX idx_phone_verification_phone ON identity.phone_verification_codes(phone);

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON identity.users 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Record migration
INSERT INTO public.schema_migrations (version, checksum) 
VALUES ('002', 'PLACEHOLDER_CHECKSUM')
ON CONFLICT (version) DO NOTHING;
