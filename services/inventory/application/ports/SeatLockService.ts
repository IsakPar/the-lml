import { Result } from '@thankful/shared';

/**
 * Seat Lock Service Port
 * Handles atomic seat locking operations with fencing tokens
 */
export interface SeatLockService {
  /**
   * Acquire lock on multiple seats atomically
   */
  acquireLocks(request: AcquireLocksRequest): Promise<Result<AcquireLocksResult, SeatLockError>>;

  /**
   * Release locks owned by user
   */
  releaseLocks(request: ReleaseLocksRequest): Promise<Result<ReleaseLocksResult, SeatLockError>>;

  /**
   * Extend lock duration
   */
  extendLocks(request: ExtendLocksRequest): Promise<Result<ExtendLocksResult, SeatLockError>>;

  /**
   * Check lock status for seats
   */
  checkLockStatus(request: CheckLockStatusRequest): Promise<Result<LockStatusResult, SeatLockError>>;

  /**
   * Get all locks for a user
   */
  getUserLocks(userId: string): Promise<Result<UserLock[], SeatLockError>>;

  /**
   * Force release expired locks (admin operation)
   */
  cleanupExpiredLocks(eventId?: string): Promise<Result<CleanupResult, SeatLockError>>;

  /**
   * Get lock statistics for an event
   */
  getLockStats(eventId: string): Promise<Result<LockStats, SeatLockError>>;
}

/**
 * Acquire locks request
 */
export interface AcquireLocksRequest {
  eventId: string;
  seatIds: string[];
  userId: string;
  sessionId?: string;
  ttlSeconds?: number; // Default: 120 seconds
  maxExtensions?: number; // Default: 1
}

/**
 * Acquire locks result
 */
export interface AcquireLocksResult {
  acquiredLocks: SeatLock[];
  failedSeats: FailedSeatLock[];
  queuedSeats: QueuedSeatLock[];
  fencingToken: string; // Master token for all acquired locks
  expiresAt: Date;
  canExtend: boolean;
}

/**
 * Failed seat lock info
 */
export interface FailedSeatLock {
  seatId: string;
  reason: LockFailureReason;
  lockedBy?: string;
  lockedUntil?: Date;
  queuePosition?: number;
}

/**
 * Queued seat lock info
 */
export interface QueuedSeatLock {
  seatId: string;
  queuePosition: number;
  estimatedWaitTime: number; // seconds
}

/**
 * Lock failure reasons
 */
export enum LockFailureReason {
  ALREADY_LOCKED = 'already_locked',
  SEAT_NOT_AVAILABLE = 'seat_not_available',
  SEAT_SOLD = 'seat_sold',
  USER_LOCK_LIMIT_EXCEEDED = 'user_lock_limit_exceeded',
  EVENT_LOCK_LIMIT_EXCEEDED = 'event_lock_limit_exceeded',
  SYSTEM_ERROR = 'system_error'
}

/**
 * Release locks request
 */
export interface ReleaseLocksRequest {
  eventId: string;
  seatIds?: string[]; // If not provided, releases all user's locks for event
  userId: string;
  fencingToken: string;
  reason?: ReleaseReason;
}

/**
 * Release reasons
 */
export enum ReleaseReason {
  USER_CANCELLED = 'user_cancelled',
  BOOKING_COMPLETED = 'booking_completed',
  EXPIRED = 'expired',
  ADMIN_OVERRIDE = 'admin_override',
  SYSTEM_CLEANUP = 'system_cleanup'
}

/**
 * Release locks result
 */
export interface ReleaseLocksResult {
  releasedSeats: string[];
  failedReleases: Array<{
    seatId: string;
    reason: string;
  }>;
  nextInQueue: Array<{
    seatId: string;
    notifiedUserId: string;
  }>;
}

/**
 * Extend locks request
 */
export interface ExtendLocksRequest {
  eventId: string;
  seatIds?: string[]; // If not provided, extends all user's locks
  userId: string;
  fencingToken: string;
  additionalSeconds: number; // Usually 60 seconds
}

/**
 * Extend locks result
 */
export interface ExtendLocksResult {
  extendedSeats: SeatLock[];
  failedExtensions: Array<{
    seatId: string;
    reason: ExtendFailureReason;
  }>;
  newExpiresAt: Date;
  extensionsRemaining: number;
}

/**
 * Extension failure reasons
 */
export enum ExtendFailureReason {
  MAX_EXTENSIONS_REACHED = 'max_extensions_reached',
  INVALID_TOKEN = 'invalid_token',
  LOCK_EXPIRED = 'lock_expired',
  LOCK_NOT_FOUND = 'lock_not_found'
}

/**
 * Check lock status request
 */
export interface CheckLockStatusRequest {
  eventId: string;
  seatIds: string[];
  userId?: string; // For checking if user owns locks
}

/**
 * Lock status result
 */
export interface LockStatusResult {
  seatStatuses: SeatStatus[];
  availableSeats: string[];
  lockedSeats: string[];
  soldSeats: string[];
}

/**
 * Individual seat status
 */
export interface SeatStatus {
  seatId: string;
  status: SeatAvailabilityStatus;
  lockedBy?: string;
  lockedUntil?: Date;
  ownedByUser?: boolean; // True if locked by requesting user
  queuePosition?: number;
  fencingToken?: string; // Only if owned by user
}

/**
 * Seat availability statuses
 */
export enum SeatAvailabilityStatus {
  AVAILABLE = 'available',
  LOCKED = 'locked',
  SOLD = 'sold',
  BLOCKED = 'blocked', // Venue/event blocked
  RESERVED = 'reserved' // VIP/special reservation
}

/**
 * Individual seat lock
 */
export interface SeatLock {
  seatId: string;
  userId: string;
  sessionId?: string;
  fencingToken: string;
  acquiredAt: Date;
  expiresAt: Date;
  extensionCount: number;
  maxExtensions: number;
}

/**
 * User lock summary
 */
export interface UserLock {
  eventId: string;
  seatIds: string[];
  fencingToken: string;
  acquiredAt: Date;
  expiresAt: Date;
  extensionCount: number;
  maxExtensions: number;
  canExtend: boolean;
}

/**
 * Cleanup result
 */
export interface CleanupResult {
  expiredLocksRemoved: number;
  seatsReleased: string[];
  usersNotified: number;
  queueProcessed: number;
}

/**
 * Lock statistics
 */
export interface LockStats {
  eventId: string;
  totalSeats: number;
  availableSeats: number;
  lockedSeats: number;
  soldSeats: number;
  activeUsers: number;
  queuedRequests: number;
  averageLockDuration: number; // seconds
  lockSuccessRate: number; // percentage
  lastUpdated: Date;
}

/**
 * Seat lock error types
 */
export interface SeatLockError {
  type: 'INVALID_REQUEST' | 'SEAT_UNAVAILABLE' | 'INVALID_TOKEN' | 'RATE_LIMITED' | 'SYSTEM_ERROR' | 'TIMEOUT';
  message: string;
  code?: string;
  details?: Record<string, any>;
  retryable?: boolean;
}

/**
 * Helper to create seat lock errors
 */
export const SeatLockError = {
  invalidRequest: (message: string, details?: Record<string, any>): SeatLockError => ({
    type: 'INVALID_REQUEST',
    message,
    details,
    retryable: false,
  }),

  seatUnavailable: (message: string, details?: Record<string, any>): SeatLockError => ({
    type: 'SEAT_UNAVAILABLE',
    message,
    details,
    retryable: true,
  }),

  invalidToken: (message: string): SeatLockError => ({
    type: 'INVALID_TOKEN',
    message,
    retryable: false,
  }),

  rateLimited: (message: string, retryAfter?: number): SeatLockError => ({
    type: 'RATE_LIMITED',
    message,
    details: { retryAfter },
    retryable: true,
  }),

  systemError: (message: string, details?: Record<string, any>): SeatLockError => ({
    type: 'SYSTEM_ERROR',
    message,
    details,
    retryable: true,
  }),

  timeout: (message: string): SeatLockError => ({
    type: 'TIMEOUT',
    message,
    retryable: true,
  }),
};
