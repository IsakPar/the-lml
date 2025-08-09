# LastMinuteLive (LML) - Complete Build Plan
*Production-Grade Ticketing Platform with DDD Architecture*

## 🎯 Executive Summary

Building a **Ticketmaster-grade** booking platform with mobile-first design, real-time seat locking, and multi-layered ticket verification. Zero MVPs - production quality from day one.

## 🏗️ Architecture Overview

### Core Principles
- **Domain-Driven Design (DDD)** with bounded contexts
- **Clean Architecture** layers (Domain → Application → Interface → Infrastructure)
- **Event-Driven** communication between contexts
- **Mobile-First** with unified API backend
- **Multi-Tenant** support for event organizers

### Technology Stack
- **Backend**: Node.js/TypeScript, Fastify, pnpm workspaces
- **Databases**: PostgreSQL (source of truth), Redis (locks/cache), MongoDB (immutable seatmaps)
- **Mobile**: React Native + iOS/Android native layers
- **Payments**: Stripe with FSM pattern
- **Infrastructure**: Docker, CI/CD, monitoring

---

## 📋 Phase 1: Foundation & Core Infrastructure
*Duration: 4-6 weeks*

### 1.1 Project Structure & DDD Foundations
**Week 1-2**

#### Bounded Contexts Setup
```
services/
├── ticketing/           # Core booking engine
├── payments/            # Stripe FSM, transactions
├── venues/              # Venue management, seatmaps
├── identity/            # Auth, user management
├── inventory/           # Real-time seat locking
└── verification/        # Ticket validation system
```

#### Each Context Structure
```
context/
├── domain/              # Entities, value objects, domain services
├── application/         # Use cases, ports (interfaces)
├── interface/           # HTTP handlers, DTOs
└── infrastructure/      # Adapters, repositories
```

**Success Metrics:**
- [ ] All 6 bounded contexts scaffolded
- [ ] Clean Architecture layers enforced
- [ ] TypeScript strict mode, 100% coverage
- [ ] pnpm workspace structure working

### 1.2 Database Layer & Migrations
**Week 2-3**

#### PostgreSQL Schema Design
```sql
-- Identity Context
CREATE TABLE users (id, email, phone, created_at, updated_at);
CREATE TABLE user_sessions (id, user_id, token_hash, expires_at);

-- Venues Context  
CREATE TABLE venues (id, name, address, capacity, created_at);
CREATE TABLE venue_sections (id, venue_id, name, capacity);
CREATE TABLE seats (id, section_id, row, number, status);

-- Ticketing Context
CREATE TABLE events (id, venue_id, name, start_time, status);
CREATE TABLE event_pricing (id, event_id, section_id, price);
CREATE TABLE bookings (id, event_id, user_id, status, total_amount);
CREATE TABLE booking_seats (id, booking_id, seat_id, price);

-- Payments Context
CREATE TABLE payment_intents (id, booking_id, stripe_intent_id, status);
CREATE TABLE payment_events (id, intent_id, event_type, data, created_at);
```

#### Redis Key Patterns
```
# Seat Locking (inventory context)
seat:lock:{event_id}:{seat_id} = {user_id, expires_at, fencing_token}
seat:queue:{event_id}:{seat_id} = [user_id1, user_id2, ...]

# Idempotency (platform layer)
idem:v1:{tenant}:{route}:{hash} = {state, result, expires_at}

# Session Management (identity context)
session:{user_id}:{device_id} = {session_data, expires_at}
```

#### MongoDB Collections
```javascript
// venues.seatmaps - Immutable venue layouts
{
  _id: ObjectId,
  venue_id: "venue_123",
  version: "v1.2",
  sections: [
    {
      id: "section_a",
      name: "Orchestra",
      seats: [
        {id: "A1", row: "A", number: 1, coordinates: {x: 100, y: 200}},
        // ... more seats
      ]
    }
  ],
  created_at: ISODate,
  published_at: ISODate
}
```

**Success Metrics:**
- [ ] All database schemas implemented
- [ ] Migration system working
- [ ] Redis patterns documented
- [ ] MongoDB collections designed
- [ ] Database adapters in each context

### 1.3 Platform Services
**Week 3-4**

#### Core Platform Packages
```
packages/
├── config/              # Environment configuration
├── http/                # Fastify setup, common middleware
├── metrics/             # Prometheus metrics, logging
├── idempotency/         # ✅ Already implemented
├── ratelimit/           # Rate limiting middleware
└── events/              # Event bus for cross-context communication
```

#### Event Bus Implementation
```typescript
// Event-driven communication between contexts
interface DomainEvent {
  id: string;
  type: string;
  aggregateId: string;
  data: unknown;
  timestamp: Date;
  version: number;
}

// Examples:
- SeatReservedEvent (inventory → ticketing)
- PaymentCompletedEvent (payments → ticketing)
- BookingConfirmedEvent (ticketing → verification)
```

**Success Metrics:**
- [ ] Event bus operational
- [ ] Metrics collection working
- [ ] Rate limiting implemented
- [ ] Configuration management
- [ ] Cross-context events flowing

---

## 🎪 Phase 2: Core Business Logic
*Duration: 6-8 weeks*

### 2.1 Identity & Authentication Service
**Week 5-6**

#### Domain Layer
```typescript
// identity/domain/
class User {
  constructor(
    private readonly id: UserId,
    private readonly email: Email,
    private readonly phone: PhoneNumber,
    private readonly profile: UserProfile
  ) {}
}

class UserSession {
  // Session management with device tracking
}
```

#### Use Cases
- Register user (email/phone verification)
- Authenticate user (password/OTP)
- Manage sessions (multi-device support)
- Role-based access control

#### API Endpoints
```
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
DELETE /api/v1/auth/logout
GET /api/v1/auth/profile
```

**Success Metrics:**
- [ ] User registration working
- [ ] Multi-device session management
- [ ] JWT token system operational
- [ ] Role-based access control
- [ ] Email/SMS verification

### 2.2 Venues & Seatmap Management
**Week 6-7**

#### Domain Layer
```typescript
// venues/domain/
class Venue {
  constructor(
    private readonly id: VenueId,
    private readonly name: string,
    private readonly address: Address,
    private readonly sections: VenueSection[]
  ) {}
}

class SeatMap {
  // Immutable seatmap with versioning
  // Coordinates for mobile rendering
}
```

#### Use Cases
- Create/update venues
- Upload seatmap layouts
- Version seatmap changes
- Generate seat coordinates for mobile

#### API Endpoints
```
GET /api/v1/venues
POST /api/v1/venues
GET /api/v1/venues/{id}/seatmap
POST /api/v1/venues/{id}/seatmap
```

**Success Metrics:**
- [ ] Venue CRUD operations
- [ ] Seatmap upload/versioning
- [ ] Coordinate system for mobile
- [ ] MongoDB integration working
- [ ] Seatmap API performance < 100ms

### 2.3 Inventory & Real-Time Seat Locking
**Week 7-8**

#### Domain Layer
```typescript
// inventory/domain/
class SeatLock {
  constructor(
    private readonly seatId: SeatId,
    private readonly userId: UserId,
    private readonly fencingToken: string,
    private readonly expiresAt: Date
  ) {}
}

class SeatInventory {
  // Manages seat availability for events
}
```

#### Redis Lua Scripts
```lua
-- acquire_seat_lock.lua
-- Atomic seat locking with fencing tokens
-- Handles queuing and TTL management

-- release_seat_lock.lua  
-- Safe lock release with fencing token validation

-- extend_seat_lock.lua
-- Extend lock TTL for active users
```

#### Use Cases
- Acquire seat lock (with queuing)
- Release seat lock  
- Extend lock TTL
- Handle lock expiration
- Bulk lock operations

**Success Metrics:**
- [ ] Sub-50ms lock acquisition
- [ ] Fencing token validation working
- [ ] Lock queuing system operational
- [ ] TTL management (120s default)
- [ ] Bulk operations support

### 2.4 Ticketing & Booking Engine
**Week 8-10**

#### Domain Layer
```typescript
// ticketing/domain/
class Booking {
  constructor(
    private readonly id: BookingId,
    private readonly eventId: EventId,
    private readonly seats: BookedSeat[],
    private readonly status: BookingStatus,
    private readonly totalAmount: Money
  ) {}

  // FSM for booking states
  // pending → confirmed → completed | cancelled
}

class Event {
  // Event management with pricing tiers
}
```

#### Finite State Machine
```
BookingStates:
PENDING → PAYMENT_PROCESSING → CONFIRMED → COMPLETED
       ↘ EXPIRED ↙               ↘ CANCELLED ↙
```

#### Use Cases
- Create booking (reserve seats)
- Process payment integration
- Confirm booking
- Cancel booking (with refund logic)
- Generate tickets

**Success Metrics:**
- [ ] Booking FSM operational
- [ ] Seat reservation working
- [ ] Payment integration ready
- [ ] Booking confirmation flow
- [ ] p99 booking time < 150ms

---

## 💳 Phase 3: Payments & Verification
*Duration: 4-5 weeks*

### 3.1 Payments Service (Stripe FSM)
**Week 11-12**

#### Domain Layer
```typescript
// payments/domain/
class PaymentIntent {
  constructor(
    private readonly id: PaymentIntentId,
    private readonly bookingId: BookingId,
    private readonly amount: Money,
    private readonly status: PaymentStatus,
    private readonly stripeIntentId: string
  ) {}
}

// FSM for payment states
enum PaymentStatus {
  CREATED = 'created',
  PROCESSING = 'processing', 
  SUCCEEDED = 'succeeded',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}
```

#### Stripe Webhook Handler
```typescript
// Handle all Stripe events with idempotency
// payment_intent.succeeded
// payment_intent.payment_failed
// charge.dispute.created
```

#### Use Cases
- Create payment intent
- Process Stripe webhooks (idempotent)
- Handle payment failures
- Process refunds
- Manage disputes

**Success Metrics:**
- [ ] Stripe integration working
- [ ] Webhook processing < 2s p99
- [ ] Payment FSM operational
- [ ] Idempotent webhook handling
- [ ] Refund system working

### 3.2 Ticket Verification Service
**Week 12-13**

#### Multi-Layer Verification Architecture
```
┌─────────────────────────────────────┐
│ Mobile App - User Layer             │
├─────────────────────────────────────┤
│ Mobile App - Verification Layer     │ ← Separate secure layer
├─────────────────────────────────────┤
│ Backend Verification Service        │
├─────────────────────────────────────┤
│ Cryptographic Validation           │
└─────────────────────────────────────┘
```

#### Domain Layer
```typescript
// verification/domain/
class Ticket {
  constructor(
    private readonly id: TicketId,
    private readonly bookingId: BookingId,
    private readonly seatId: SeatId,
    private readonly qrCode: EncryptedQRCode,
    private readonly validationHash: string
  ) {}
}

class VerificationRequest {
  // Handles ticket scanning requests
  // Includes location validation
}
```

#### Ticket Security
- **QR Code**: Encrypted payload with timestamp
- **Validation Hash**: HMAC with secret rotation
- **Location Verification**: GPS validation at venue
- **Time Windows**: Ticket valid only during event

#### Use Cases
- Generate secure tickets
- Validate ticket authenticity
- Check-in attendees
- Handle duplicate scans
- Location-based validation

**Success Metrics:**
- [ ] Secure ticket generation
- [ ] QR code validation < 200ms
- [ ] Location verification working
- [ ] Duplicate scan prevention
- [ ] Mobile app security layers

---

## 📱 Phase 4: Mobile Applications
*Duration: 6-8 weeks*

### 4.1 Mobile App Architecture
**Week 14-16**

#### User Layer (React Native)
```
src/
├── screens/           # User-facing screens
├── components/        # Reusable UI components  
├── navigation/        # App navigation
├── services/          # API clients
└── store/             # State management
```

#### Verification Layer (Native)
```
ios/VerificationSDK/   # Native iOS module
android/verification/  # Native Android module

- Secure keystore access
- Hardware-backed cryptography
- Anti-tampering measures
- Secure ticket validation
```

#### Core Features
- Event browsing & search
- Interactive seatmap selection
- Real-time seat availability
- Secure payment processing
- Ticket wallet with offline support
- Venue check-in with GPS validation

**Success Metrics:**
- [ ] React Native app running
- [ ] Native verification modules
- [ ] Seatmap rendering performance
- [ ] Offline ticket storage
- [ ] Hardware security integration

### 4.2 Real-Time Features
**Week 16-17**

#### WebSocket Integration
```typescript
// Real-time seat availability updates
// Booking status notifications
// Payment confirmations
// Queue position updates
```

#### State Management
- Redux Toolkit for app state
- React Query for server state
- Optimistic updates for UX
- Conflict resolution for seat locks

**Success Metrics:**
- [ ] Real-time seat updates
- [ ] WebSocket connectivity stable
- [ ] Optimistic UI working
- [ ] Offline-first architecture

### 4.3 Verification App Features
**Week 17-18**

#### Venue Staff App
- Ticket scanning interface
- Bulk check-in capabilities
- Offline validation support
- Admin dashboard access
- Real-time attendance tracking

#### Security Features
- Role-based scanner access
- Audit trail for all scans
- Fraud detection alerts
- Emergency lockdown mode

**Success Metrics:**
- [ ] Scanner app operational
- [ ] Offline verification working
- [ ] Audit trail complete
- [ ] Admin dashboard functional

---

## 🚀 Phase 5: Platform & DevOps
*Duration: 3-4 weeks*

### 5.1 API Gateway & Rate Limiting
**Week 19**

#### Gateway Features
- Request routing by context
- Rate limiting per user/IP
- API versioning support
- Request/response logging
- Circuit breaker pattern

#### Rate Limiting Rules
```
# Seat operations (high-value)
/seats/hold: 10 req/min per user
/seats/release: 20 req/min per user

# Authentication
/auth/*: 20 req/min per IP

# General API
/api/v1/*: 100 req/min per user
```

**Success Metrics:**
- [ ] API gateway operational
- [ ] Rate limiting working
- [ ] Circuit breakers tested
- [ ] API versioning support

### 5.2 Monitoring & Observability
**Week 19-20**

#### Metrics Collection
```
# Business Metrics
- booking_success_rate
- seat_lock_conflicts
- payment_completion_rate
- ticket_verification_rate

# Technical Metrics  
- api_response_times
- database_connection_pool
- redis_cache_hit_rate
- webhook_processing_delays
```

#### Distributed Tracing
- Request correlation across contexts
- Performance bottleneck identification
- Error propagation tracking
- SLA monitoring

**Success Metrics:**
- [ ] Prometheus metrics working
- [ ] Grafana dashboards created
- [ ] Alerting rules configured
- [ ] Distributed tracing operational

### 5.3 Deployment & CI/CD
**Week 20-21**

#### Docker Containerization
```dockerfile
# Multi-stage builds for each service
# Minimal production images
# Health check endpoints
# Graceful shutdown handling
```

#### CI/CD Pipeline
```yaml
# GitHub Actions workflow
1. Code quality checks (linting, formatting)
2. Type checking (TypeScript strict)
3. Unit tests (coverage > 80%)
4. Integration tests
5. Security scanning
6. Docker build & push
7. Deployment to staging
8. E2E tests
9. Production deployment
```

**Success Metrics:**
- [ ] All services containerized
- [ ] CI/CD pipeline working
- [ ] Automated testing > 80% coverage
- [ ] Security scanning integrated
- [ ] Blue-green deployments

---

## 📊 Success Metrics & KPIs

### Technical Performance
- **API Response Times**: p99 < 150ms for booking operations
- **Seat Lock Acquisition**: < 50ms average
- **Payment Processing**: < 2s end-to-end
- **Mobile App Performance**: 60fps seatmap rendering
- **System Availability**: 99.9% uptime

### Business Metrics
- **Booking Conversion Rate**: > 85%
- **Payment Success Rate**: > 98%
- **Seat Lock Conflicts**: < 2% during peak
- **Mobile App Crashes**: < 0.1%
- **Ticket Verification Time**: < 3s average

### Security & Compliance
- **Zero** data breaches
- **100%** ticket authenticity
- **Sub-second** fraud detection
- **Complete** audit trails
- **PCI DSS** compliance for payments

---

## 🔄 Ongoing Maintenance & Iteration

### Monthly Reviews
- Performance optimization
- Security updates
- User feedback integration
- A/B testing results
- Capacity planning

### Quarterly Releases
- New features based on user data
- Platform scalability improvements
- Mobile app updates
- API versioning strategy

---

## 🎯 Final Deliverables

### Production-Ready Platform
1. **6 Microservices** with clean DDD architecture
2. **Mobile Apps** (iOS/Android) with secure verification
3. **Admin Dashboard** for venue management
4. **Real-time System** with WebSocket support
5. **Payment Processing** with Stripe integration
6. **Monitoring Stack** with full observability
7. **CI/CD Pipeline** with automated deployments

### Documentation
- API documentation (OpenAPI)
- Architecture decision records
- Deployment runbooks
- Security protocols
- User manuals

This plan transforms the current foundation into a **complete, production-grade ticketing platform** that can compete directly with Ticketmaster while maintaining clean architecture and security standards throughout.
