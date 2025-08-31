import { Result } from '@thankful/result';

/**
 * Generic Venue Staff Repository Port
 * Manages venue staff for any venue with proper isolation
 */
export interface VenueStaffRepository {
  /**
   * Create a venue staff member
   */
  create(venueStaff: CreateVenueStaffData): Promise<Result<VenueStaff, RepositoryError>>;

  /**
   * Find venue staff by ID
   */
  findById(id: string): Promise<Result<VenueStaff | null, RepositoryError>>;

  /**
   * Find venue staff by user ID and venue ID
   */
  findByUserAndVenue(userId: string, venueId: string): Promise<Result<VenueStaff | null, RepositoryError>>;

  /**
   * Find all staff for a venue
   */
  findByVenue(venueId: string, options?: FindStaffOptions): Promise<Result<VenueStaffResult, RepositoryError>>;

  /**
   * Find staff by role within a venue
   */
  findByVenueAndRole(venueId: string, role: string): Promise<Result<VenueStaff[], RepositoryError>>;

  /**
   * Update venue staff
   */
  update(id: string, updates: UpdateVenueStaffData): Promise<Result<VenueStaff, RepositoryError>>;

  /**
   * Deactivate venue staff
   */
  deactivate(id: string, deactivatedBy: string, reason?: string): Promise<Result<void, RepositoryError>>;

  /**
   * Count staff for a venue
   */
  countByVenue(venueId: string, filters?: StaffCountFilters): Promise<Result<number, RepositoryError>>;

  /**
   * Check if user already has staff role in venue
   */
  hasStaffRole(userId: string, venueId: string): Promise<Result<boolean, RepositoryError>>;
}

/**
 * Venue Staff data structures
 */
export interface VenueStaff {
  id: string;
  userId: string;
  venueId: string;
  role: VenueStaffRole;
  permissions: VenueStaffPermissions;
  jobTitle?: string;
  department?: string;
  employeeId?: string;
  status: VenueStaffStatus;
  invitedAt?: Date;
  activatedAt?: Date;
  lastActivityAt?: Date;
  createdAt: Date;
  createdBy?: string;
  updatedAt: Date;
  updatedBy?: string;
}

export interface CreateVenueStaffData {
  userId: string;
  venueId: string;
  role: VenueStaffRole;
  permissions?: VenueStaffPermissions;
  jobTitle?: string;
  department?: string;
  employeeId?: string;
  createdBy: string;
}

export interface UpdateVenueStaffData {
  role?: VenueStaffRole;
  permissions?: VenueStaffPermissions;
  jobTitle?: string;
  department?: string;
  employeeId?: string;
  status?: VenueStaffStatus;
  updatedBy: string;
}

export interface VenueStaffPermissions {
  customers: {
    read: boolean;
    update: boolean;
    delete: boolean;
    export?: boolean;
  };
  shows: {
    read: boolean;
    create: boolean;
    update: boolean;
    delete: boolean;
  };
  tickets: {
    validate: boolean;
    refund: boolean;
    transfer: boolean;
    comp?: boolean;
  };
  analytics: {
    read: boolean;
    export: boolean;
    dashboard?: boolean;
  };
  staff: {
    read: boolean;
    invite: boolean;
    manage: boolean;
    permissions?: boolean;
  };
  venue: {
    settings: boolean;
    branding: boolean;
    configuration: boolean;
  };
}

export enum VenueStaffRole {
  VENUE_ADMIN = 'VenueAdmin',
  VENUE_STAFF = 'VenueStaff',
  VENUE_VALIDATOR = 'VenueValidator',
  BOX_OFFICE = 'BoxOffice',
  SECURITY = 'Security'
}

export enum VenueStaffStatus {
  PENDING = 'pending',
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  TERMINATED = 'terminated'
}

/**
 * Query options and filters
 */
export interface FindStaffOptions {
  limit?: number;
  offset?: number;
  role?: VenueStaffRole;
  status?: VenueStaffStatus;
  sortBy?: 'created_at' | 'updated_at' | 'last_activity_at';
  sortOrder?: 'asc' | 'desc';
}

export interface StaffCountFilters {
  role?: VenueStaffRole;
  status?: VenueStaffStatus;
  department?: string;
}

export interface VenueStaffResult {
  staff: VenueStaff[];
  total: number;
  limit: number;
  offset: number;
  hasMore: boolean;
}

/**
 * Repository error (reused from VenueAccountRepository)
 */
export class RepositoryError extends Error {
  constructor(
    message: string,
    public readonly code: RepositoryErrorCode,
    public readonly cause?: Error
  ) {
    super(message);
    this.name = 'RepositoryError';
  }
}

export enum RepositoryErrorCode {
  CONNECTION_FAILED = 'CONNECTION_FAILED',
  QUERY_FAILED = 'QUERY_FAILED',
  NOT_FOUND = 'NOT_FOUND',
  CONSTRAINT_VIOLATION = 'CONSTRAINT_VIOLATION',
  CONCURRENCY_CONFLICT = 'CONCURRENCY_CONFLICT',
  TIMEOUT = 'TIMEOUT',
  UNKNOWN = 'UNKNOWN'
}


