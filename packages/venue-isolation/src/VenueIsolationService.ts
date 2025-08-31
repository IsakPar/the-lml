import { Result } from '@thankful/result';
import { Logger } from '@thankful/logging';
import { 
  VenueContext, 
  VenueAccessError, 
  VenueAccessErrorCode, 
  VenueBoundaryViolation,
  BoundaryViolationError,
  VenueIsolationConfig,
  VenuePermissions
} from './types.js';

/**
 * Core venue isolation service
 * Manages venue contexts, enforces boundaries, and validates access
 */
export class VenueIsolationService {
  private readonly logger: Logger;

  constructor(
    private readonly config: VenueIsolationConfig,
    logger?: Logger
  ) {
    this.logger = logger || new Logger({ service: 'venue-isolation' });
  }

  /**
   * Create a venue context for the given venue and user
   */
  async createVenueContext(
    venueId: string,
    userId?: string,
    correlationId?: string
  ): Promise<Result<VenueContext, VenueAccessError>> {
    try {
      this.logger.info('Creating venue context', {
        venueId,
        userId,
        correlationId
      });

      // Validate venue exists and is active
      const venueValidation = await this.validateVenue(venueId);
      if (!venueValidation.success) {
        return Result.failure(venueValidation.error);
      }
      const venue = venueValidation.value;

      // If user provided, validate their access to this venue
      let userRole: string = 'anonymous';
      let venueRole: string = 'none';
      let permissions: VenuePermissions = this.config.defaultPermissions;
      let isLMLAdmin = false;

      if (userId) {
        const userValidation = await this.validateUserVenueAccess(userId, venueId);
        if (!userValidation.success) {
          return Result.failure(userValidation.error);
        }
        const userAccess = userValidation.value;
        
        userRole = userAccess.userRole;
        venueRole = userAccess.venueRole;
        permissions = userAccess.permissions;
        isLMLAdmin = userAccess.isLMLAdmin;
      }

      const context: VenueContext = {
        venueId,
        venueName: venue.name,
        venueSlug: venue.slug,
        userId,
        userRole,
        venueRole,
        permissions,
        isLMLAdmin,
        correlationId
      };

      this.logger.debug('Venue context created successfully', {
        context,
        correlationId
      });

      return Result.success(context);
    } catch (error) {
      this.logger.error('Failed to create venue context', {
        error: error.message,
        venueId,
        userId,
        correlationId
      });

      return Result.failure(new VenueAccessError(
        'Failed to create venue context',
        VenueAccessErrorCode.VENUE_NOT_FOUND
      ));
    }
  }

  /**
   * Execute operation within venue context with automatic isolation
   */
  async executeInVenueContext<T>(
    venueId: string,
    userId: string,
    operation: (context: VenueContext) => Promise<T>,
    correlationId?: string
  ): Promise<Result<T, VenueAccessError | BoundaryViolationError>> {
    const contextResult = await this.createVenueContext(venueId, userId, correlationId);
    if (!contextResult.success) {
      return Result.failure(contextResult.error);
    }

    const context = contextResult.value;

    try {
      // Set database context for RLS
      await this.setDatabaseVenueContext(context);

      // Execute operation with venue context
      const result = await operation(context);

      // Log successful access
      if (this.config.auditAllAccess) {
        await this.auditVenueAccess(context, 'operation_success', true);
      }

      return Result.success(result);
    } catch (error) {
      this.logger.error('Operation failed in venue context', {
        error: error.message,
        context,
        correlationId
      });

      // Log failed access
      if (this.config.auditAllAccess) {
        await this.auditVenueAccess(context, 'operation_failed', false, error.message);
      }

      if (error instanceof VenueAccessError || error instanceof BoundaryViolationError) {
        return Result.failure(error);
      }

      return Result.failure(new VenueAccessError(
        'Operation failed in venue context',
        VenueAccessErrorCode.BOUNDARY_VIOLATION,
        venueId,
        userId
      ));
    } finally {
      // Clean up database context
      await this.clearDatabaseVenueContext();
    }
  }

  /**
   * Validate that a user has access to a specific venue
   */
  async validateUserVenueAccess(
    userId: string,
    venueId: string
  ): Promise<Result<{
    userRole: string;
    venueRole: string;
    permissions: VenuePermissions;
    isLMLAdmin: boolean;
  }, VenueAccessError>> {
    try {
      // This would query the database to check user's venue access
      // For now, returning a placeholder implementation
      
      // TODO: Implement actual database query using venue-scoped repositories
      const mockUserAccess = {
        userRole: 'user',
        venueRole: 'VenueStaff',
        permissions: this.config.defaultPermissions,
        isLMLAdmin: false
      };

      this.logger.debug('User venue access validated', {
        userId,
        venueId,
        access: mockUserAccess
      });

      return Result.success(mockUserAccess);
    } catch (error) {
      this.logger.error('Failed to validate user venue access', {
        error: error.message,
        userId,
        venueId
      });

      return Result.failure(new VenueAccessError(
        'User does not have access to this venue',
        VenueAccessErrorCode.NO_VENUE_ACCESS,
        venueId,
        userId
      ));
    }
  }

  /**
   * Check if user has specific permission for venue operation
   */
  checkVenuePermission(
    context: VenueContext,
    resource: keyof VenuePermissions,
    action: string
  ): boolean {
    // LML Admins have full access
    if (context.isLMLAdmin) {
      return true;
    }

    const resourcePermissions = context.permissions[resource];
    if (!resourcePermissions) {
      return false;
    }

    // Check specific action permission
    return resourcePermissions[action as keyof typeof resourcePermissions] === true;
  }

  /**
   * Enforce venue boundary by checking attempted venue against user's venue
   */
  async enforceVenueBoundary(
    userId: string,
    attemptedVenue: string,
    operation: string,
    requestInfo?: {
      ipAddress?: string;
      userAgent?: string;
      requestPath?: string;
    }
  ): Promise<Result<void, BoundaryViolationError>> {
    try {
      // Get user's assigned venue
      const userVenueResult = await this.getUserAssignedVenue(userId);
      if (!userVenueResult.success) {
        // If user has no assigned venue, they might be a customer (allow access)
        return Result.success(undefined);
      }

      const userVenue = userVenueResult.value;

      // Check if user is trying to access different venue
      if (userVenue !== attemptedVenue && this.config.blockCrossVenueAccess) {
        const violation: VenueBoundaryViolation = {
          userId,
          attemptedVenue,
          userVenue,
          operation,
          timestamp: new Date(),
          ipAddress: requestInfo?.ipAddress,
          userAgent: requestInfo?.userAgent,
          requestPath: requestInfo?.requestPath
        };

        // Log boundary violation
        if (this.config.logBoundaryViolations) {
          await this.logBoundaryViolation(violation);
        }

        return Result.failure(new BoundaryViolationError(
          `User from venue ${userVenue} attempted to access venue ${attemptedVenue}`,
          violation
        ));
      }

      return Result.success(undefined);
    } catch (error) {
      this.logger.error('Failed to enforce venue boundary', {
        error: error.message,
        userId,
        attemptedVenue,
        operation
      });

      return Result.failure(new BoundaryViolationError(
        'Boundary enforcement failed',
        {
          userId,
          attemptedVenue,
          userVenue: 'unknown',
          operation,
          timestamp: new Date()
        }
      ));
    }
  }

  /**
   * Private helper methods
   */
  private async validateVenue(venueId: string): Promise<Result<{
    name: string;
    slug: string;
    status: string;
  }, VenueAccessError>> {
    // TODO: Implement actual database query
    // For now, return mock data
    return Result.success({
      name: 'Hamilton',
      slug: 'hamilton',
      status: 'active'
    });
  }

  private async getUserAssignedVenue(userId: string): Promise<Result<string, VenueAccessError>> {
    // TODO: Implement actual database query
    // Return null for now (user has no assigned venue)
    return Result.failure(new VenueAccessError(
      'No venue assigned',
      VenueAccessErrorCode.NO_VENUE_ACCESS,
      undefined,
      userId
    ));
  }

  private async setDatabaseVenueContext(context: VenueContext): Promise<void> {
    // TODO: Implement database context setting for RLS
    // This would set the venue_id and user_id in the database session
    this.logger.debug('Setting database venue context', {
      venueId: context.venueId,
      userId: context.userId,
      correlationId: context.correlationId
    });
  }

  private async clearDatabaseVenueContext(): Promise<void> {
    // TODO: Implement database context clearing
    this.logger.debug('Clearing database venue context');
  }

  private async auditVenueAccess(
    context: VenueContext,
    operation: string,
    success: boolean,
    errorMessage?: string
  ): Promise<void> {
    this.logger.info('Venue access audit', {
      venueId: context.venueId,
      userId: context.userId,
      operation,
      success,
      errorMessage,
      correlationId: context.correlationId,
      timestamp: new Date().toISOString()
    });

    // TODO: Store audit trail in database
  }

  private async logBoundaryViolation(violation: VenueBoundaryViolation): Promise<void> {
    this.logger.warn('Venue boundary violation detected', {
      violation,
      severity: 'HIGH',
      action: 'ACCESS_BLOCKED'
    });

    // TODO: Store violation in database and potentially alert administrators
  }
}

