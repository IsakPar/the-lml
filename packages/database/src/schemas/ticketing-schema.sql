-- Ticketing Bounded Context Schema
-- Handles events, bookings, and ticket management with FSM support

-- Events with comprehensive pricing and scheduling
CREATE TABLE ticketing.events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id UUID NOT NULL, -- Reference to venues.venues(id)
  organizer_id UUID NOT NULL, -- Reference to identity.users(id)
  
  -- Event details
  name VARCHAR(200) NOT NULL,
  slug VARCHAR(200) UNIQUE NOT NULL,
  description TEXT,
  category VARCHAR(50) NOT NULL, -- concert, sports, theater, conference, etc.
  
  -- Scheduling with timezone support
  event_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  event_end_time TIMESTAMP WITH TIME ZONE,
  doors_open_time TIMESTAMP WITH TIME ZONE,
  timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
  
  -- Sales periods
  sale_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  sale_end_time TIMESTAMP WITH TIME ZONE,
  presale_start_time TIMESTAMP WITH TIME ZONE,
  
  -- Capacity and limits
  total_capacity INTEGER NOT NULL,
  max_tickets_per_user INTEGER DEFAULT 8,
  
  -- Event characteristics
  age_restriction INTEGER, -- 0 = all ages, 18 = adults only, etc.
  requires_id_verification BOOLEAN NOT NULL DEFAULT false,
  is_seated_event BOOLEAN NOT NULL DEFAULT true,
  
  -- Status management (FSM states)
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  
  -- SEO and marketing
  image_url TEXT,
  banner_image_url TEXT,
  meta_description TEXT,
  tags JSONB DEFAULT '[]',
  
  -- Business rules
  is_published BOOLEAN NOT NULL DEFAULT false,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  published_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  
  -- Constraints
  CONSTRAINT events_capacity_positive CHECK (total_capacity > 0),
  CONSTRAINT events_name_not_empty CHECK (name != ''),
  CONSTRAINT events_status_valid CHECK (status IN ('draft', 'published', 'on_sale', 'sold_out', 'cancelled', 'postponed', 'completed')),
  CONSTRAINT events_times_logical CHECK (event_start_time > sale_start_time),
  CONSTRAINT events_age_restriction_valid CHECK (age_restriction IS NULL OR age_restriction BETWEEN 0 AND 99),
  CONSTRAINT events_max_tickets_reasonable CHECK (max_tickets_per_user BETWEEN 1 AND 50)
);

-- Event pricing tiers with dynamic pricing support
CREATE TABLE ticketing.event_pricing (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES ticketing.events(id) ON DELETE CASCADE,
  section_id UUID, -- Reference to venues.venue_sections(id), NULL for general admission
  
  -- Pricing tier information
  tier_name VARCHAR(100) NOT NULL, -- 'General Admission', 'VIP', 'Early Bird', etc.
  tier_type VARCHAR(50) NOT NULL DEFAULT 'standard', -- standard, early_bird, vip, group, student
  
  -- Pricing details (stored in cents for precision)
  base_price_cents INTEGER NOT NULL,
  service_fee_cents INTEGER NOT NULL DEFAULT 0,
  processing_fee_cents INTEGER NOT NULL DEFAULT 0,
  
  -- Dynamic pricing
  current_price_cents INTEGER, -- Can change based on demand
  min_price_cents INTEGER,
  max_price_cents INTEGER,
  
  -- Availability
  total_quantity INTEGER,
  remaining_quantity INTEGER,
  
  -- Sales periods
  sale_start_time TIMESTAMP WITH TIME ZONE,
  sale_end_time TIMESTAMP WITH TIME ZONE,
  
  -- Business rules
  is_active BOOLEAN NOT NULL DEFAULT true,
  requires_approval BOOLEAN NOT NULL DEFAULT false, -- For group sales, etc.
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT pricing_base_price_positive CHECK (base_price_cents > 0),
  CONSTRAINT pricing_fees_non_negative CHECK (service_fee_cents >= 0 AND processing_fee_cents >= 0),
  CONSTRAINT pricing_quantities_consistent CHECK (remaining_quantity <= total_quantity),
  CONSTRAINT pricing_dynamic_range_valid CHECK (
    min_price_cents IS NULL OR max_price_cents IS NULL OR min_price_cents <= max_price_cents
  ),
  CONSTRAINT pricing_tier_type_valid CHECK (tier_type IN ('standard', 'early_bird', 'vip', 'group', 'student', 'senior'))
);

-- Bookings with comprehensive FSM state management
CREATE TABLE ticketing.bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES ticketing.events(id),
  user_id UUID NOT NULL, -- Reference to identity.users(id)
  
  -- Booking identification
  booking_reference VARCHAR(20) UNIQUE NOT NULL, -- Human-readable reference
  
  -- Pricing summary
  subtotal_cents INTEGER NOT NULL,
  service_fees_cents INTEGER NOT NULL DEFAULT 0,
  processing_fees_cents INTEGER NOT NULL DEFAULT 0,
  taxes_cents INTEGER NOT NULL DEFAULT 0,
  total_amount_cents INTEGER NOT NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'USD',
  
  -- FSM State management
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  
  -- Important timestamps for business logic
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  confirmed_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  
  -- Customer information
  customer_email VARCHAR(254) NOT NULL,
  customer_phone VARCHAR(20),
  billing_address JSONB,
  
  -- Business metadata
  booking_source VARCHAR(50) NOT NULL DEFAULT 'web', -- web, mobile, api, admin
  special_requests TEXT,
  notes TEXT, -- Internal notes
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT bookings_amounts_positive CHECK (
    subtotal_cents > 0 AND 
    service_fees_cents >= 0 AND 
    processing_fees_cents >= 0 AND 
    taxes_cents >= 0 AND 
    total_amount_cents > 0
  ),
  CONSTRAINT bookings_status_valid CHECK (status IN (
    'pending', 'payment_processing', 'confirmed', 'completed', 'cancelled', 'expired', 'refunded'
  )),
  CONSTRAINT bookings_expires_future CHECK (expires_at > created_at),
  CONSTRAINT bookings_currency_valid CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT bookings_source_valid CHECK (booking_source IN ('web', 'mobile', 'api', 'admin', 'phone'))
);

-- Individual booked seats with precise tracking
CREATE TABLE ticketing.booking_seats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES ticketing.bookings(id) ON DELETE CASCADE,
  seat_id UUID, -- Reference to venues.seats(id), NULL for general admission
  pricing_tier_id UUID NOT NULL REFERENCES ticketing.event_pricing(id),
  
  -- Seat details (denormalized for performance)
  section_name VARCHAR(100),
  row_identifier VARCHAR(10),
  seat_number INTEGER,
  
  -- Pricing at time of booking (immutable)
  base_price_cents INTEGER NOT NULL,
  service_fee_cents INTEGER NOT NULL DEFAULT 0,
  processing_fee_cents INTEGER NOT NULL DEFAULT 0,
  taxes_cents INTEGER NOT NULL DEFAULT 0,
  total_price_cents INTEGER NOT NULL,
  
  -- Individual seat status
  status VARCHAR(50) NOT NULL DEFAULT 'reserved',
  
  -- Ticket information
  ticket_number VARCHAR(50) UNIQUE,
  qr_code_data TEXT, -- Encrypted QR code payload
  
  -- Check-in tracking
  checked_in_at TIMESTAMP WITH TIME ZONE,
  checked_in_by UUID, -- Reference to identity.users(id) for staff
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT booking_seats_prices_positive CHECK (
    base_price_cents > 0 AND 
    service_fee_cents >= 0 AND 
    processing_fee_cents >= 0 AND 
    taxes_cents >= 0 AND 
    total_price_cents > 0
  ),
  CONSTRAINT booking_seats_status_valid CHECK (status IN ('reserved', 'confirmed', 'checked_in', 'cancelled')),
  
  -- For general admission, seat details should be NULL
  CONSTRAINT booking_seats_general_admission_logic CHECK (
    (seat_id IS NULL AND section_name IS NULL AND row_identifier IS NULL AND seat_number IS NULL) OR
    (seat_id IS NOT NULL AND section_name IS NOT NULL)
  )
);

-- Booking state change history for audit and debugging
CREATE TABLE ticketing.booking_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES ticketing.bookings(id) ON DELETE CASCADE,
  from_status VARCHAR(50),
  to_status VARCHAR(50) NOT NULL,
  reason VARCHAR(200),
  metadata JSONB,
  changed_by UUID, -- Reference to identity.users(id)
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_events_venue_id ON ticketing.events(venue_id);
CREATE INDEX idx_events_organizer_id ON ticketing.events(organizer_id);
CREATE INDEX idx_events_status ON ticketing.events(status);
CREATE INDEX idx_events_start_time ON ticketing.events(event_start_time);
CREATE INDEX idx_events_sale_times ON ticketing.events(sale_start_time, sale_end_time);
CREATE INDEX idx_events_published ON ticketing.events(is_published);
CREATE INDEX idx_events_featured ON ticketing.events(is_featured);
CREATE INDEX idx_events_category ON ticketing.events(category);

CREATE INDEX idx_pricing_event_id ON ticketing.event_pricing(event_id);
CREATE INDEX idx_pricing_section_id ON ticketing.event_pricing(section_id);
CREATE INDEX idx_pricing_active ON ticketing.event_pricing(is_active);
CREATE INDEX idx_pricing_sale_times ON ticketing.event_pricing(sale_start_time, sale_end_time);

CREATE INDEX idx_bookings_event_id ON ticketing.bookings(event_id);
CREATE INDEX idx_bookings_user_id ON ticketing.bookings(user_id);
CREATE INDEX idx_bookings_status ON ticketing.bookings(status);
CREATE INDEX idx_bookings_reference ON ticketing.bookings(booking_reference);
CREATE INDEX idx_bookings_expires_at ON ticketing.bookings(expires_at);
CREATE INDEX idx_bookings_created_at ON ticketing.bookings(created_at);

CREATE INDEX idx_booking_seats_booking_id ON ticketing.booking_seats(booking_id);
CREATE INDEX idx_booking_seats_seat_id ON ticketing.booking_seats(seat_id);
CREATE INDEX idx_booking_seats_pricing_tier ON ticketing.booking_seats(pricing_tier_id);
CREATE INDEX idx_booking_seats_status ON ticketing.booking_seats(status);
CREATE INDEX idx_booking_seats_ticket_number ON ticketing.booking_seats(ticket_number);

CREATE INDEX idx_status_history_booking_id ON ticketing.booking_status_history(booking_id);
CREATE INDEX idx_status_history_created_at ON ticketing.booking_status_history(created_at);

-- Triggers for updated_at
CREATE TRIGGER update_events_updated_at 
  BEFORE UPDATE ON ticketing.events 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pricing_updated_at 
  BEFORE UPDATE ON ticketing.event_pricing 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at 
  BEFORE UPDATE ON ticketing.bookings 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger to track booking status changes
CREATE OR REPLACE FUNCTION track_booking_status_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO ticketing.booking_status_history (booking_id, from_status, to_status, reason)
    VALUES (NEW.id, OLD.status, NEW.status, 'Status changed via update');
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER track_booking_status_changes
  AFTER UPDATE ON ticketing.bookings
  FOR EACH ROW
  EXECUTE FUNCTION track_booking_status_changes();
