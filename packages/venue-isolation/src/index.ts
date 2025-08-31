/**
 * @thankful/venue-isolation
 * 
 * Provides venue isolation utilities, middleware, and services for multi-tenant 
 * venue management with strict data boundaries and access control.
 */

// Core services
export { VenueIsolationService } from './VenueIsolationService.js';
export { VenueIsolationMiddleware } from './VenueIsolationMiddleware.js';
export { VenueScopedRepository } from './VenueScopedRepository.js';

// Types and interfaces
export {
  VenueContext,
  VenuePermissions,
  PermissionSet,
  VenueAccessToken,
  VenueBoundaryViolation,
  VenueIsolationConfig,
  DatabaseConnectionOptions,
  VenueAccessError,
  VenueAccessErrorCode,
  BoundaryViolationError
} from './types.js';

// Utility functions
export {
  createDefaultVenuePermissions,
  createVenueIsolationConfig,
  createVenueMiddlewareStack
} from './utils.js';

