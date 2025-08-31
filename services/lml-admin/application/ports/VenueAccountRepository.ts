import { Result } from '@thankful/result';
import { VenueAccount } from '../../domain/entities/VenueAccount.js';

/**
 * Generic Venue Account Repository Port
 * Defines contract for venue account persistence - works for any venue
 */
export interface VenueAccountRepository {
  /**
   * Save a venue account (create or update)
   */
  save(venueAccount: VenueAccount): Promise<Result<VenueAccount, RepositoryError>>;

  /**
   * Find venue account by ID
   */
  findById(id: string): Promise<Result<VenueAccount | null, RepositoryError>>;

  /**
   * Find venue account by slug
   */
  findBySlug(slug: string): Promise<Result<VenueAccount | null, RepositoryError>>;

  /**
   * Find all venue accounts with pagination
   */
  findAll(options?: FindAllOptions): Promise<Result<VenueAccountSearchResult, RepositoryError>>;

  /**
   * Find venue accounts by status
   */
  findByStatus(status: string, options?: FindAllOptions): Promise<Result<VenueAccount[], RepositoryError>>;

  /**
   * Search venue accounts
   */
  search(criteria: VenueAccountSearchCriteria): Promise<Result<VenueAccountSearchResult, RepositoryError>>;

  /**
   * Check if venue slug is available
   */
  isSlugAvailable(slug: string): Promise<Result<boolean, RepositoryError>>;

  /**
   * Archive venue account (soft delete)
   */
  archive(id: string, archivedBy: string): Promise<Result<void, RepositoryError>>;

  /**
   * Count total venue accounts
   */
  count(criteria?: VenueAccountCountCriteria): Promise<Result<number, RepositoryError>>;
}

/**
 * Repository search criteria
 */
export interface VenueAccountSearchCriteria {
  name?: string;
  slug?: string;
  status?: string;
  createdBy?: string;
  createdAfter?: Date;
  createdBefore?: Date;
}

export interface VenueAccountCountCriteria {
  status?: string;
  createdAfter?: Date;
  createdBefore?: Date;
}

/**
 * Find options for pagination and sorting
 */
export interface FindAllOptions {
  limit?: number;
  offset?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

/**
 * Search result with pagination
 */
export interface VenueAccountSearchResult {
  venues: VenueAccount[];
  total: number;
  limit: number;
  offset: number;
  hasMore: boolean;
}

/**
 * Repository error types
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

