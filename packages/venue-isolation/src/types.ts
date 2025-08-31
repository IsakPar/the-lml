/**
 * Core types for venue isolation system
 */

export interface VenueContext {
  venueId: string;
  venueName: string;
  venueSlug: string;
  userId?: string;
  userRole?: string;
  venueRole?: string;
  permissions: VenuePermissions;
  isLMLAdmin: boolean;
  correlationId?: string;
}

export interface VenuePermissions {
  customers: PermissionSet;
  shows: PermissionSet;
  tickets: PermissionSet;
  analytics: PermissionSet;
  staff: PermissionSet;
  venue: PermissionSet;
}

export interface PermissionSet {
  read: boolean;
  create: boolean;
  update: boolean;
  delete: boolean;
  export?: boolean;
  manage?: boolean;
  validate?: boolean;
  refund?: boolean;
}

export interface VenueAccessToken {
  userId: string;
  venueId: string;
  venueRole: string;
  permissions: VenuePermissions;
  isLMLAdmin: boolean;
  exp: number;
  iat: number;
}

export interface VenueBoundaryViolation {
  userId: string;
  attemptedVenue: string;
  userVenue: string;
  operation: string;
  timestamp: Date;
  ipAddress?: string;
  userAgent?: string;
  requestPath?: string;
}

export class VenueAccessError extends Error {
  constructor(
    message: string,
    public readonly code: VenueAccessErrorCode,
    public readonly venueId?: string,
    public readonly userId?: string
  ) {
    super(message);
    this.name = 'VenueAccessError';
  }
}

export enum VenueAccessErrorCode {
  NO_VENUE_ACCESS = 'NO_VENUE_ACCESS',
  WRONG_VENUE = 'WRONG_VENUE',
  INSUFFICIENT_PERMISSIONS = 'INSUFFICIENT_PERMISSIONS',
  VENUE_NOT_FOUND = 'VENUE_NOT_FOUND',
  USER_NOT_FOUND = 'USER_NOT_FOUND',
  INVALID_TOKEN = 'INVALID_TOKEN',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  VENUE_SUSPENDED = 'VENUE_SUSPENDED',
  BOUNDARY_VIOLATION = 'BOUNDARY_VIOLATION'
}

export class BoundaryViolationError extends Error {
  constructor(
    message: string,
    public readonly violation: VenueBoundaryViolation
  ) {
    super(message);
    this.name = 'BoundaryViolationError';
  }
}

export interface VenueIsolationConfig {
  enableStrictIsolation: boolean;
  logBoundaryViolations: boolean;
  blockCrossVenueAccess: boolean;
  auditAllAccess: boolean;
  defaultPermissions: VenuePermissions;
  tokenExpiryHours: number;
  maxTokenRefreshes: number;
}

export interface DatabaseConnectionOptions {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  ssl?: boolean;
  pool?: {
    min: number;
    max: number;
    idle: number;
  };
}

