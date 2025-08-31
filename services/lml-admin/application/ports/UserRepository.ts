import { Result } from '@thankful/result';
import { RepositoryError } from './VenueAccountRepository.js';

/**
 * Generic User Repository Port for venue admin system
 * Handles user creation and venue association
 */
export interface UserRepository {
  /**
   * Create a new user
   */
  create(userData: CreateUserData): Promise<Result<User, RepositoryError>>;

  /**
   * Find user by ID
   */
  findById(id: string): Promise<Result<User | null, RepositoryError>>;

  /**
   * Find user by email
   */
  findByEmail(email: string): Promise<Result<User | null, RepositoryError>>;

  /**
   * Update user's venue association
   */
  updateVenueAssociation(userId: string, venueId: string): Promise<Result<User, RepositoryError>>;

  /**
   * Update user profile
   */
  update(userId: string, updates: UpdateUserData): Promise<Result<User, RepositoryError>>;

  /**
   * Set user password (for venue admin accounts)
   */
  setPassword(userId: string, passwordHash: string): Promise<Result<void, RepositoryError>>;

  /**
   * Verify user email
   */
  verifyEmail(userId: string): Promise<Result<void, RepositoryError>>;

  /**
   * Find users by venue ID
   */
  findByVenue(venueId: string): Promise<Result<User[], RepositoryError>>;

  /**
   * Check if email is already taken
   */
  emailExists(email: string): Promise<Result<boolean, RepositoryError>>;
}

/**
 * User data structures
 */
export interface User {
  id: string;
  email: string;
  name: string;
  phone?: string;
  role: string;
  venueId?: string;
  lmlAdminRole?: string;
  isEmailVerified: boolean;
  isPhoneVerified: boolean;
  passwordHash?: string;
  createdAt: Date;
  updatedAt: Date;
  lastLoginAt?: Date;
  createdBy?: string;
}

export interface CreateUserData {
  email: string;
  name: string;
  phone?: string;
  role: string;
  venueId?: string;
  lmlAdminRole?: string;
  passwordHash?: string;
  isEmailVerified?: boolean;
  createdBy?: string;
}

export interface UpdateUserData {
  name?: string;
  phone?: string;
  role?: string;
  venueId?: string;
  lmlAdminRole?: string;
  isEmailVerified?: boolean;
  isPhoneVerified?: boolean;
  updatedBy?: string;
}


