/**
 * Common types used across all bounded contexts
 */
export type UserId = string;
export type VenueId = string;
export type EventId = string;
export type BookingId = string;
export type SeatId = string;
export type PaymentId = string;
export type TicketId = string;
export interface Money {
    readonly amount: number;
    readonly currency: string;
}
export interface Address {
    readonly street: string;
    readonly city: string;
    readonly state: string;
    readonly postalCode: string;
    readonly country: string;
}
export interface Coordinate {
    readonly x: number;
    readonly y: number;
}
export declare enum BookingStatus {
    PENDING = "pending",
    PAYMENT_PROCESSING = "payment_processing",
    CONFIRMED = "confirmed",
    COMPLETED = "completed",
    CANCELLED = "cancelled",
    EXPIRED = "expired"
}
export declare enum PaymentStatus {
    CREATED = "created",
    PROCESSING = "processing",
    SUCCEEDED = "succeeded",
    FAILED = "failed",
    CANCELLED = "cancelled"
}
export declare enum SeatStatus {
    AVAILABLE = "available",
    LOCKED = "locked",
    RESERVED = "reserved",
    SOLD = "sold"
}
export declare enum UserRole {
    USER = "user",
    ORGANIZER_ADMIN = "organizer_admin",
    SUPPORT = "support",
    SUPER_ADMIN = "super_admin"
}
