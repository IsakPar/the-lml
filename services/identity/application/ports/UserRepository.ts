import { Result } from '@thankful/shared';
import { User } from '../../domain/entities/User.js';
import { Email } from '../../domain/valueobjects/Email.js';
import { PhoneNumber } from '../../domain/valueobjects/PhoneNumber.js';

/**
 * User Repository Port
 * Defines the contract for user data persistence
 */
export interface UserRepository {
  /**
   * Save a user (create or update)
   */
  save(user: User): Promise<Result<User, RepositoryError>>;

  /**
   * Find user by ID
   */
  findById(id: string): Promise<Result<User | null, RepositoryError>>;

  /**
   * Find user by email
   */
  findByEmail(email: Email): Promise<Result<User | null, RepositoryError>>;

  /**
   * Find user by phone number
   */
  findByPhone(phone: PhoneNumber): Promise<Result<User | null, RepositoryError>>;

  /**
   * Check if email is already taken
   */
  emailExists(email: Email): Promise<Result<boolean, RepositoryError>>;

  /**
   * Check if phone is already taken
   */
  phoneExists(phone: PhoneNumber): Promise<Result<boolean, RepositoryError>>;

  /**
   * Get users by role
   */
  findByRole(role: UserRole): Promise<Result<User[], RepositoryError>>;

  /**
   * Search users with pagination
   */
  search(criteria: UserSearchCriteria): Promise<Result<UserSearchResult, RepositoryError>>;

  /**
   * Delete user (soft delete)
   */
  delete(id: string): Promise<Result<void, RepositoryError>>;

  /**
   * Update last login time
   */
  updateLastLogin(id: string): Promise<Result<void, RepositoryError>>;
}

/**
 * User search criteria
 */
export interface UserSearchCriteria {
  email?: string;
  phone?: string;
  role?: UserRole;
  isEmailVerified?: boolean;
  isPhoneVerified?: boolean;
  createdAfter?: Date;
  createdBefore?: Date;
  page?: number;
  limit?: number;
  sortBy?: 'created_at' | 'last_login_at' | 'email';
  sortOrder?: 'asc' | 'desc';
}

/**
 * User search result
 */
export interface UserSearchResult {
  users: User[];
  total: number;
  page: number;
  pages: number;
  hasNext: boolean;
  hasPrev: boolean;
}

/**
 * User roles enum
 */
export enum UserRole {
  USER = 'user',
  ORGANIZER_ADMIN = 'organizer_admin',
  SUPPORT = 'support',
  SUPER_ADMIN = 'super_admin'
}

/**
 * Repository error types
 */
export interface RepositoryError {
  type: 'CONNECTION_ERROR' | 'CONSTRAINT_VIOLATION' | 'NOT_FOUND' | 'TIMEOUT' | 'UNKNOWN';
  message: string;
  code?: string;
  details?: Record<string, any>;
}

/**
 * Helper to create repository errors
 */
export const RepositoryError = {
  connectionError: (message: string, details?: Record<string, any>): RepositoryError => ({
    type: 'CONNECTION_ERROR',
    message,
    details,
  }),

  constraintViolation: (message: string, code?: string, details?: Record<string, any>): RepositoryError => ({
    type: 'CONSTRAINT_VIOLATION',
    message,
    code,
    details,
  }),

  notFound: (message: string): RepositoryError => ({
    type: 'NOT_FOUND',
    message,
  }),

  timeout: (message: string): RepositoryError => ({
    type: 'TIMEOUT',
    message,
  }),

  unknown: (message: string, details?: Record<string, any>): RepositoryError => ({
    type: 'UNKNOWN',
    message,
    details,
  }),
};
