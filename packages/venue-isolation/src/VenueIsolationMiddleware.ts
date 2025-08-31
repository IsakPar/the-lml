import { Request, Response, NextFunction } from 'express';
import { Logger } from '@thankful/logging';
import { VenueIsolationService } from './VenueIsolationService.js';
import { 
  VenueContext, 
  VenueAccessError, 
  BoundaryViolationError,
  VenueAccessErrorCode 
} from './types.js';

// Extend Express Request to include venue context
declare global {
  namespace Express {
    interface Request {
      venueContext?: VenueContext;
      user?: {
        id: string;
        role: string;
        venueId?: string;
      };
      correlationId?: string;
    }
  }
}

/**
 * Express middleware for venue isolation and boundary enforcement
 */
export class VenueIsolationMiddleware {
  private readonly logger: Logger;

  constructor(
    private readonly venueIsolationService: VenueIsolationService,
    logger?: Logger
  ) {
    this.logger = logger || new Logger({ service: 'venue-isolation-middleware' });
  }

  /**
   * Extract venue ID from request path
   * Expects routes like: /api/v1/venues/:venueId/...
   */
  extractVenueId = (req: Request, res: Response, next: NextFunction): void => {
    try {
      const venueId = req.params.venueId;
      
      if (!venueId) {
        this.logger.warn('No venue ID found in request path', {
          path: req.path,
          params: req.params,
          correlationId: req.correlationId
        });
        
        res.status(400).json({
          type: 'https://thankful.com/errors/venue-required',
          title: 'Venue ID Required',
          status: 400,
          detail: 'Venue ID must be provided in the request path',
          details: {
            code: 'VENUE_ID_REQUIRED'
          }
        });
        return;
      }

      // Store venue ID for later middleware to use
      req.params.venueId = venueId;
      
      this.logger.debug('Venue ID extracted from request', {
        venueId,
        path: req.path,
        correlationId: req.correlationId
      });

      next();
    } catch (error) {
      this.logger.error('Failed to extract venue ID', {
        error: error.message,
        path: req.path,
        correlationId: req.correlationId
      });

      res.status(500).json({
        type: 'https://thankful.com/errors/venue-extraction-failed',
        title: 'Venue Extraction Failed',
        status: 500,
        detail: 'Failed to extract venue information from request',
        details: {
          code: 'VENUE_EXTRACTION_FAILED'
        }
      });
    }
  };

  /**
   * Create and validate venue context for the request
   */
  createVenueContext = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const venueId = req.params.venueId;
      const userId = req.user?.id;
      const correlationId = req.correlationId;

      if (!venueId) {
        res.status(400).json({
          type: 'https://thankful.com/errors/venue-required',
          title: 'Venue ID Required',
          status: 400,
          detail: 'Venue ID is required for this operation',
          details: {
            code: 'VENUE_ID_REQUIRED'
          }
        });
        return;
      }

      const contextResult = await this.venueIsolationService.createVenueContext(
        venueId,
        userId,
        correlationId
      );

      if (!contextResult.success) {
        const error = contextResult.error;
        this.logger.warn('Failed to create venue context', {
          error: error.message,
          venueId,
          userId,
          correlationId
        });

        const statusCode = this.mapErrorToStatusCode(error);
        
        res.status(statusCode).json({
          type: 'https://thankful.com/errors/venue-access-denied',
          title: 'Venue Access Denied',
          status: statusCode,
          detail: error.message,
          details: {
            code: error.code,
            venue_id: error.venueId,
            user_id: error.userId
          }
        });
        return;
      }

      // Attach venue context to request
      req.venueContext = contextResult.value;

      this.logger.debug('Venue context created and attached to request', {
        venueId,
        userId,
        correlationId,
        userRole: req.venueContext.userRole,
        venueRole: req.venueContext.venueRole
      });

      next();
    } catch (error) {
      this.logger.error('Unexpected error creating venue context', {
        error: error.message,
        venueId: req.params.venueId,
        userId: req.user?.id,
        correlationId: req.correlationId
      });

      res.status(500).json({
        type: 'https://thankful.com/errors/venue-context-failed',
        title: 'Venue Context Creation Failed',
        status: 500,
        detail: 'Failed to create venue context',
        details: {
          code: 'VENUE_CONTEXT_FAILED'
        }
      });
    }
  };

  /**
   * Enforce venue boundary protection
   */
  enforceVenueBoundary = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user?.id;
      const venueId = req.params.venueId;
      const operation = `${req.method} ${req.path}`;

      if (!userId) {
        // Allow anonymous access for public endpoints
        next();
        return;
      }

      if (!venueId) {
        res.status(400).json({
          type: 'https://thankful.com/errors/venue-required',
          title: 'Venue ID Required',
          status: 400,
          detail: 'Venue ID is required for boundary enforcement',
          details: {
            code: 'VENUE_ID_REQUIRED'
          }
        });
        return;
      }

      const boundaryResult = await this.venueIsolationService.enforceVenueBoundary(
        userId,
        venueId,
        operation,
        {
          ipAddress: req.ip,
          userAgent: req.get('User-Agent'),
          requestPath: req.path
        }
      );

      if (!boundaryResult.success) {
        const error = boundaryResult.error;
        this.logger.warn('Venue boundary violation detected', {
          error: error.message,
          violation: error.violation,
          correlationId: req.correlationId
        });

        res.status(403).json({
          type: 'https://thankful.com/errors/venue-boundary-violation',
          title: 'Venue Boundary Violation',
          status: 403,
          detail: 'Access denied: Cross-venue access not permitted',
          details: {
            code: 'VENUE_BOUNDARY_VIOLATION',
            attempted_venue: error.violation.attemptedVenue,
            user_venue: error.violation.userVenue,
            operation: error.violation.operation
          }
        });
        return;
      }

      this.logger.debug('Venue boundary check passed', {
        userId,
        venueId,
        operation,
        correlationId: req.correlationId
      });

      next();
    } catch (error) {
      this.logger.error('Unexpected error in venue boundary enforcement', {
        error: error.message,
        userId: req.user?.id,
        venueId: req.params.venueId,
        correlationId: req.correlationId
      });

      res.status(500).json({
        type: 'https://thankful.com/errors/boundary-enforcement-failed',
        title: 'Boundary Enforcement Failed',
        status: 500,
        detail: 'Failed to enforce venue boundary',
        details: {
          code: 'BOUNDARY_ENFORCEMENT_FAILED'
        }
      });
    }
  };

  /**
   * Require specific venue permission for endpoint access
   */
  requireVenuePermission = (
    resource: string,
    action: string
  ) => {
    return (req: Request, res: Response, next: NextFunction): void => {
      try {
        if (!req.venueContext) {
          res.status(401).json({
            type: 'https://thankful.com/errors/venue-context-missing',
            title: 'Venue Context Missing',
            status: 401,
            detail: 'Venue context is required for this operation',
            details: {
              code: 'VENUE_CONTEXT_MISSING'
            }
          });
          return;
        }

        const hasPermission = this.venueIsolationService.checkVenuePermission(
          req.venueContext,
          resource as any,
          action
        );

        if (!hasPermission) {
          this.logger.warn('Venue permission denied', {
            userId: req.user?.id,
            venueId: req.venueContext.venueId,
            resource,
            action,
            userPermissions: req.venueContext.permissions,
            correlationId: req.correlationId
          });

          res.status(403).json({
            type: 'https://thankful.com/errors/venue-permission-denied',
            title: 'Venue Permission Denied',
            status: 403,
            detail: `Insufficient permissions for ${action} on ${resource}`,
            details: {
              code: 'VENUE_PERMISSION_DENIED',
              required_resource: resource,
              required_action: action,
              user_role: req.venueContext.venueRole
            }
          });
          return;
        }

        this.logger.debug('Venue permission granted', {
          userId: req.user?.id,
          venueId: req.venueContext.venueId,
          resource,
          action,
          correlationId: req.correlationId
        });

        next();
      } catch (error) {
        this.logger.error('Error checking venue permission', {
          error: error.message,
          resource,
          action,
          userId: req.user?.id,
          venueId: req.venueContext?.venueId,
          correlationId: req.correlationId
        });

        res.status(500).json({
          type: 'https://thankful.com/errors/permission-check-failed',
          title: 'Permission Check Failed',
          status: 500,
          detail: 'Failed to check venue permissions',
          details: {
            code: 'PERMISSION_CHECK_FAILED'
          }
        });
      }
    };
  };

  /**
   * Map venue access errors to HTTP status codes
   */
  private mapErrorToStatusCode(error: VenueAccessError): number {
    switch (error.code) {
      case VenueAccessErrorCode.NO_VENUE_ACCESS:
      case VenueAccessErrorCode.INSUFFICIENT_PERMISSIONS:
        return 403;
      case VenueAccessErrorCode.VENUE_NOT_FOUND:
      case VenueAccessErrorCode.USER_NOT_FOUND:
        return 404;
      case VenueAccessErrorCode.INVALID_TOKEN:
      case VenueAccessErrorCode.TOKEN_EXPIRED:
        return 401;
      case VenueAccessErrorCode.VENUE_SUSPENDED:
        return 423; // Locked
      case VenueAccessErrorCode.WRONG_VENUE:
      case VenueAccessErrorCode.BOUNDARY_VIOLATION:
        return 403;
      default:
        return 500;
    }
  }

  /**
   * Create a composed middleware stack for venue-scoped routes
   */
  createVenueMiddlewareStack() {
    return [
      this.extractVenueId,
      this.createVenueContext,
      this.enforceVenueBoundary
    ];
  }
}

