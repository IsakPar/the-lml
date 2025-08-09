/**
 * Common types used across all bounded contexts
 */

// ID types for type safety
export type UserId = string;
export type VenueId = string;
export type EventId = string;
export type BookingId = string;
export type SeatId = string;
export type PaymentId = string;
export type TicketId = string;

// Money value object for financial calculations
export interface Money {
  readonly amount: number; // Amount in smallest currency unit (cents)
  readonly currency: string; // ISO 4217 currency code
}

// Address value object
export interface Address {
  readonly street: string;
  readonly city: string;
  readonly state: string;
  readonly postalCode: string;
  readonly country: string;
}

// Coordinate for seat positioning
export interface Coordinate {
  readonly x: number;
  readonly y: number;
}

// Common enums
export enum BookingStatus {
  PENDING = 'pending',
  PAYMENT_PROCESSING = 'payment_processing',
  CONFIRMED = 'confirmed',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired'
}

export enum PaymentStatus {
  CREATED = 'created',
  PROCESSING = 'processing',
  SUCCEEDED = 'succeeded',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}

export enum SeatStatus {
  AVAILABLE = 'available',
  LOCKED = 'locked',
  RESERVED = 'reserved',
  SOLD = 'sold'
}

export enum UserRole {
  USER = 'user',
  ORGANIZER_ADMIN = 'organizer_admin',
  SUPPORT = 'support',
  SUPER_ADMIN = 'super_admin'
}
