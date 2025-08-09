-- Venues Bounded Context Schema
-- Handles venue management, sections, and seat layouts

-- Venues with comprehensive address and capacity management
CREATE TABLE venues.venues (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  slug VARCHAR(200) UNIQUE NOT NULL,
  
  -- Address components for international support
  street_address TEXT NOT NULL,
  city VARCHAR(100) NOT NULL,
  state_province VARCHAR(100),
  postal_code VARCHAR(20),
  country_code CHAR(2) NOT NULL, -- ISO 3166-1 alpha-2
  
  -- Venue characteristics
  total_capacity INTEGER NOT NULL,
  venue_type VARCHAR(50) NOT NULL DEFAULT 'indoor', -- indoor, outdoor, amphitheater, stadium
  description TEXT,
  facilities JSONB DEFAULT '[]', -- ["parking", "wheelchair_accessible", "food_court"]
  
  -- Contact and business information
  phone VARCHAR(20),
  email VARCHAR(254),
  website_url TEXT,
  
  -- Geographic coordinates for mobile apps
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  
  -- Business rules
  is_active BOOLEAN NOT NULL DEFAULT true,
  requires_age_verification BOOLEAN NOT NULL DEFAULT false,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT venues_capacity_positive CHECK (total_capacity > 0),
  CONSTRAINT venues_capacity_reasonable CHECK (total_capacity <= 1000000),
  CONSTRAINT venues_name_not_empty CHECK (name != ''),
  CONSTRAINT venues_venue_type_valid CHECK (venue_type IN ('indoor', 'outdoor', 'amphitheater', 'stadium', 'arena')),
  CONSTRAINT venues_coordinates_valid CHECK (
    (latitude IS NULL AND longitude IS NULL) OR 
    (latitude IS NOT NULL AND longitude IS NOT NULL AND 
     latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
  )
);

-- Venue sections with detailed layout information
CREATE TABLE venues.venue_sections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID NOT NULL REFERENCES venues.venues(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  section_type VARCHAR(50) NOT NULL DEFAULT 'general', -- general, vip, accessible, standing
  
  -- Capacity and layout
  capacity INTEGER NOT NULL,
  row_count INTEGER,
  avg_seats_per_row DECIMAL(5,2),
  
  -- Visual positioning for mobile rendering
  position_x INTEGER NOT NULL DEFAULT 0,
  position_y INTEGER NOT NULL DEFAULT 0,
  width INTEGER,
  height INTEGER,
  rotation_degrees INTEGER DEFAULT 0,
  
  -- Pricing and access controls
  is_premium BOOLEAN NOT NULL DEFAULT false,
  requires_special_access BOOLEAN NOT NULL DEFAULT false,
  accessibility_features JSONB DEFAULT '[]', -- ["wheelchair", "hearing_loop", "companion_seat"]
  
  -- Visual styling for mobile apps
  color_hex CHAR(7) DEFAULT '#3498db',
  display_order INTEGER NOT NULL DEFAULT 0,
  
  -- Business rules
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT sections_capacity_positive CHECK (capacity > 0),
  CONSTRAINT sections_name_not_empty CHECK (name != ''),
  CONSTRAINT sections_section_type_valid CHECK (section_type IN ('general', 'vip', 'accessible', 'standing', 'box')),
  CONSTRAINT sections_color_valid CHECK (color_hex ~* '^#[0-9a-f]{6}$'),
  CONSTRAINT sections_rotation_valid CHECK (rotation_degrees BETWEEN 0 AND 359),
  
  -- Ensure section name is unique within venue
  UNIQUE(venue_id, name)
);

-- Individual seats with precise positioning
CREATE TABLE venues.seats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  section_id UUID NOT NULL REFERENCES venues.venue_sections(id) ON DELETE CASCADE,
  
  -- Seat identification
  row_identifier VARCHAR(10) NOT NULL, -- 'A', 'B', '1', '2', etc.
  seat_number INTEGER NOT NULL,
  
  -- Precise coordinates for mobile rendering (relative to section)
  x_coordinate DECIMAL(10, 4) NOT NULL,
  y_coordinate DECIMAL(10, 4) NOT NULL,
  
  -- Seat characteristics
  seat_type VARCHAR(50) NOT NULL DEFAULT 'standard', -- standard, premium, accessible, companion
  is_accessible BOOLEAN NOT NULL DEFAULT false,
  is_companion_seat BOOLEAN NOT NULL DEFAULT false, -- For accessibility companions
  
  -- Viewing characteristics
  sight_line_rating INTEGER CHECK (sight_line_rating BETWEEN 1 AND 10),
  viewing_angle_degrees INTEGER,
  distance_to_stage_meters DECIMAL(8, 2),
  
  -- Business rules
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_obstructed_view BOOLEAN NOT NULL DEFAULT false,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT seats_seat_number_positive CHECK (seat_number > 0),
  CONSTRAINT seats_seat_type_valid CHECK (seat_type IN ('standard', 'premium', 'accessible', 'companion', 'box')),
  CONSTRAINT seats_coordinates_positive CHECK (x_coordinate >= 0 AND y_coordinate >= 0),
  
  -- Ensure seat is unique within section
  UNIQUE(section_id, row_identifier, seat_number)
);

-- Venue amenities and facilities
CREATE TABLE venues.venue_amenities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID NOT NULL REFERENCES venues.venues(id) ON DELETE CASCADE,
  amenity_type VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  location_description TEXT,
  is_accessible BOOLEAN NOT NULL DEFAULT false,
  operating_hours JSONB, -- {"monday": "9:00-17:00", "tuesday": "closed"}
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  CONSTRAINT amenities_type_valid CHECK (amenity_type IN (
    'parking', 'restroom', 'concession', 'gift_shop', 'atm', 'first_aid', 
    'lost_and_found', 'customer_service', 'merchandise', 'food_court'
  ))
);

-- Indexes for performance
CREATE INDEX idx_venues_slug ON venues.venues(slug);
CREATE INDEX idx_venues_city ON venues.venues(city);
CREATE INDEX idx_venues_country ON venues.venues(country_code);
CREATE INDEX idx_venues_active ON venues.venues(is_active);
CREATE INDEX idx_venues_capacity ON venues.venues(total_capacity);
CREATE INDEX idx_venues_coordinates ON venues.venues(latitude, longitude);

CREATE INDEX idx_sections_venue_id ON venues.venue_sections(venue_id);
CREATE INDEX idx_sections_type ON venues.venue_sections(section_type);
CREATE INDEX idx_sections_active ON venues.venue_sections(is_active);
CREATE INDEX idx_sections_display_order ON venues.venue_sections(display_order);

CREATE INDEX idx_seats_section_id ON venues.seats(section_id);
CREATE INDEX idx_seats_row_seat ON venues.seats(row_identifier, seat_number);
CREATE INDEX idx_seats_type ON venues.seats(seat_type);
CREATE INDEX idx_seats_accessible ON venues.seats(is_accessible);
CREATE INDEX idx_seats_active ON venues.seats(is_active);

CREATE INDEX idx_amenities_venue_id ON venues.venue_amenities(venue_id);
CREATE INDEX idx_amenities_type ON venues.venue_amenities(amenity_type);

-- Triggers for updated_at
CREATE TRIGGER update_venues_updated_at 
  BEFORE UPDATE ON venues.venues 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sections_updated_at 
  BEFORE UPDATE ON venues.venue_sections 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();
