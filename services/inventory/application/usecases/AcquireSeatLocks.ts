import { Result } from '@thankful/shared';
import { 
  SeatLockService, 
  AcquireLocksRequest, 
  AcquireLocksResult, 
  SeatLockError,
  LockFailureReason,
  SeatAvailabilityStatus 
} from '../ports/SeatLockService.js';

/**
 * Acquire Seat Locks Use Case
 * Orchestrates the atomic acquisition of multiple seat locks
 */
export class AcquireSeatLocks {
  constructor(
    private seatLockService: SeatLockService,
    private rateLimitService: RateLimitService,
    private eventValidationService: EventValidationService
  ) {}

  /**
   * Execute seat lock acquisition
   */
  async execute(command: AcquireSeatLocksCommand): Promise<Result<SeatLockAcquisitionResult, SeatLockAcquisitionError>> {
    // Validate command
    const validationResult = this.validateCommand(command);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error);
    }

    // Check rate limits
    const rateLimitResult = await this.rateLimitService.checkLimit(command.userId, 'seat_lock');
    if (rateLimitResult.isFailure || !rateLimitResult.value.allowed) {
      return Result.failure(SeatLockAcquisitionError.rateLimited(
        'Too many lock requests. Please wait before trying again.',
        rateLimitResult.value?.retryAfterSeconds
      ));
    }

    // Validate event is active and on sale
    const eventValidation = await this.eventValidationService.validateEventForBooking(command.eventId);
    if (eventValidation.isFailure) {
      return Result.failure(SeatLockAcquisitionError.eventNotAvailable(eventValidation.error.message));
    }

    // Check user's existing locks to prevent excessive holding
    const userLocksResult = await this.seatLockService.getUserLocks(command.userId);
    if (userLocksResult.isFailure) {
      return Result.failure(SeatLockAcquisitionError.systemError('Failed to check existing locks'));
    }

    const existingLockCount = userLocksResult.value.reduce((total, lock) => total + lock.seatIds.length, 0);
    const maxLocksPerUser = eventValidation.value.maxTicketsPerUser || 8;
    
    if (existingLockCount + command.seatIds.length > maxLocksPerUser) {
      return Result.failure(SeatLockAcquisitionError.lockLimitExceeded(
        `Cannot exceed ${maxLocksPerUser} seats per user. Currently holding ${existingLockCount} seats.`
      ));
    }

    // Prepare lock request
    const lockRequest: AcquireLocksRequest = {
      eventId: command.eventId,
      seatIds: command.seatIds,
      userId: command.userId,
      sessionId: command.sessionId,
      ttlSeconds: command.ttlSeconds || this.getDefaultTTL(command.eventId),
      maxExtensions: command.maxExtensions || 1,
    };

    // Attempt to acquire locks
    const lockResult = await this.seatLockService.acquireLocks(lockRequest);
    if (lockResult.isFailure) {
      // Increment rate limit counter on failure to prevent abuse
      await this.rateLimitService.recordAttempt(command.userId, 'seat_lock');
      
      return Result.failure(SeatLockAcquisitionError.fromSeatLockError(lockResult.error));
    }

    const acquisitionResult = lockResult.value;

    // Analyze results and provide user feedback
    const result: SeatLockAcquisitionResult = {
      requestId: this.generateRequestId(),
      eventId: command.eventId,
      userId: command.userId,
      
      // Successfully acquired locks
      acquiredSeats: acquisitionResult.acquiredLocks.map(lock => ({
        seatId: lock.seatId,
        section: this.extractSectionFromSeatId(lock.seatId),
        row: this.extractRowFromSeatId(lock.seatId),
        seatNumber: this.extractSeatNumberFromSeatId(lock.seatId),
        expiresAt: lock.expiresAt,
        fencingToken: lock.fencingToken,
      })),
      
      // Failed seat attempts
      failedSeats: acquisitionResult.failedSeats.map(failed => ({
        seatId: failed.seatId,
        reason: failed.reason,
        message: this.getFailureMessage(failed.reason),
        lockedUntil: failed.lockedUntil,
        queuePosition: failed.queuePosition,
      })),
      
      // Queued seats (for future notification)
      queuedSeats: acquisitionResult.queuedSeats.map(queued => ({
        seatId: queued.seatId,
        queuePosition: queued.queuePosition,
        estimatedWaitTime: queued.estimatedWaitTime,
      })),
      
      // Summary
      summary: {
        requested: command.seatIds.length,
        acquired: acquisitionResult.acquiredLocks.length,
        failed: acquisitionResult.failedSeats.length,
        queued: acquisitionResult.queuedSeats.length,
        isPartialSuccess: acquisitionResult.acquiredLocks.length > 0 && acquisitionResult.acquiredLocks.length < command.seatIds.length,
        isFullSuccess: acquisitionResult.acquiredLocks.length === command.seatIds.length,
      },
      
      // Lock management
      masterFencingToken: acquisitionResult.fencingToken,
      expiresAt: acquisitionResult.expiresAt,
      canExtend: acquisitionResult.canExtend,
      
      // Next actions
      nextActions: this.getNextActions(acquisitionResult),
    };

    // Record successful attempt for rate limiting
    await this.rateLimitService.recordAttempt(command.userId, 'seat_lock');

    return Result.success(result);
  }

  /**
   * Validate the acquisition command
   */
  private validateCommand(command: AcquireSeatLocksCommand): Result<void, SeatLockAcquisitionError> {
    const errors: string[] = [];

    if (!command.eventId?.trim()) {
      errors.push('Event ID is required');
    }

    if (!command.userId?.trim()) {
      errors.push('User ID is required');
    }

    if (!command.seatIds || command.seatIds.length === 0) {
      errors.push('At least one seat ID is required');
    }

    if (command.seatIds && command.seatIds.length > 20) {
      errors.push('Cannot request more than 20 seats at once');
    }

    if (command.ttlSeconds && (command.ttlSeconds < 30 || command.ttlSeconds > 900)) {
      errors.push('TTL must be between 30 and 900 seconds');
    }

    // Check for duplicate seat IDs
    if (command.seatIds) {
      const uniqueSeats = new Set(command.seatIds);
      if (uniqueSeats.size !== command.seatIds.length) {
        errors.push('Duplicate seat IDs are not allowed');
      }
    }

    if (errors.length > 0) {
      return Result.failure(SeatLockAcquisitionError.validationError('Command validation failed', errors));
    }

    return Result.success(undefined);
  }

  /**
   * Get default TTL based on event demand
   */
  private getDefaultTTL(eventId: string): number {
    // Could be dynamic based on event popularity
    return 120; // 2 minutes default
  }

  /**
   * Generate unique request ID for tracking
   */
  private generateRequestId(): string {
    return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Extract section from seat ID (format: "venue_section_row_seat")
   */
  private extractSectionFromSeatId(seatId: string): string {
    const parts = seatId.split('_');
    return parts[1] || 'Unknown';
  }

  /**
   * Extract row from seat ID
   */
  private extractRowFromSeatId(seatId: string): string {
    const parts = seatId.split('_');
    return parts[2] || 'Unknown';
  }

  /**
   * Extract seat number from seat ID
   */
  private extractSeatNumberFromSeatId(seatId: string): string {
    const parts = seatId.split('_');
    return parts[3] || 'Unknown';
  }

  /**
   * Get user-friendly failure message
   */
  private getFailureMessage(reason: LockFailureReason): string {
    switch (reason) {
      case LockFailureReason.ALREADY_LOCKED:
        return 'This seat is currently being held by another user';
      case LockFailureReason.SEAT_SOLD:
        return 'This seat has already been sold';
      case LockFailureReason.SEAT_NOT_AVAILABLE:
        return 'This seat is not available for selection';
      case LockFailureReason.USER_LOCK_LIMIT_EXCEEDED:
        return 'You have reached the maximum number of seats you can hold';
      case LockFailureReason.EVENT_LOCK_LIMIT_EXCEEDED:
        return 'Event capacity limit reached';
      default:
        return 'Unable to secure this seat at this time';
    }
  }

  /**
   * Get next actions based on acquisition result
   */
  private getNextActions(result: AcquireLocksResult): string[] {
    const actions: string[] = [];

    if (result.acquiredLocks.length > 0) {
      actions.push('Proceed to checkout to complete your purchase');
      
      if (result.canExtend) {
        actions.push('You can extend your hold time if needed');
      }
    }

    if (result.queuedSeats.length > 0) {
      actions.push('You will be notified if queued seats become available');
    }

    if (result.failedSeats.length > 0) {
      actions.push('Consider selecting alternative seats');
    }

    return actions;
  }
}

// Supporting interfaces and services

/**
 * Rate limit service interface
 */
interface RateLimitService {
  checkLimit(userId: string, operation: string): Promise<Result<{ allowed: boolean; retryAfterSeconds?: number }, any>>;
  recordAttempt(userId: string, operation: string): Promise<void>;
}

/**
 * Event validation service interface
 */
interface EventValidationService {
  validateEventForBooking(eventId: string): Promise<Result<{ isOnSale: boolean; maxTicketsPerUser: number }, { message: string }>>;
}

/**
 * Command interface
 */
export interface AcquireSeatLocksCommand {
  eventId: string;
  seatIds: string[];
  userId: string;
  sessionId?: string;
  ttlSeconds?: number;
  maxExtensions?: number;
}

/**
 * Result interface
 */
export interface SeatLockAcquisitionResult {
  requestId: string;
  eventId: string;
  userId: string;
  acquiredSeats: Array<{
    seatId: string;
    section: string;
    row: string;
    seatNumber: string;
    expiresAt: Date;
    fencingToken: string;
  }>;
  failedSeats: Array<{
    seatId: string;
    reason: LockFailureReason;
    message: string;
    lockedUntil?: Date;
    queuePosition?: number;
  }>;
  queuedSeats: Array<{
    seatId: string;
    queuePosition: number;
    estimatedWaitTime: number;
  }>;
  summary: {
    requested: number;
    acquired: number;
    failed: number;
    queued: number;
    isPartialSuccess: boolean;
    isFullSuccess: boolean;
  };
  masterFencingToken: string;
  expiresAt: Date;
  canExtend: boolean;
  nextActions: string[];
}

/**
 * Error interface
 */
export interface SeatLockAcquisitionError {
  type: 'VALIDATION_ERROR' | 'RATE_LIMITED' | 'EVENT_NOT_AVAILABLE' | 'LOCK_LIMIT_EXCEEDED' | 'SYSTEM_ERROR';
  message: string;
  details?: string[];
  retryAfterSeconds?: number;
  retryable?: boolean;
}

/**
 * Helper to create acquisition errors
 */
export const SeatLockAcquisitionError = {
  validationError: (message: string, details: string[]): SeatLockAcquisitionError => ({
    type: 'VALIDATION_ERROR',
    message,
    details,
    retryable: false,
  }),

  rateLimited: (message: string, retryAfterSeconds?: number): SeatLockAcquisitionError => ({
    type: 'RATE_LIMITED',
    message,
    retryAfterSeconds,
    retryable: true,
  }),

  eventNotAvailable: (message: string): SeatLockAcquisitionError => ({
    type: 'EVENT_NOT_AVAILABLE',
    message,
    retryable: false,
  }),

  lockLimitExceeded: (message: string): SeatLockAcquisitionError => ({
    type: 'LOCK_LIMIT_EXCEEDED',
    message,
    retryable: false,
  }),

  systemError: (message: string): SeatLockAcquisitionError => ({
    type: 'SYSTEM_ERROR',
    message,
    retryable: true,
  }),

  fromSeatLockError: (error: SeatLockError): SeatLockAcquisitionError => ({
    type: 'SYSTEM_ERROR',
    message: error.message,
    retryable: error.retryable,
  }),
};
