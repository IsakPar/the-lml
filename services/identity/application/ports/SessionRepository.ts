import { Result } from '@thankful/shared';
import { RepositoryError } from './UserRepository.js';

/**
 * User Session Repository Port
 * Handles session persistence and management
 */
export interface SessionRepository {
  /**
   * Create a new session
   */
  create(session: UserSession): Promise<Result<UserSession, RepositoryError>>;

  /**
   * Find session by token hash
   */
  findByToken(tokenHash: string): Promise<Result<UserSession | null, RepositoryError>>;

  /**
   * Find all active sessions for a user
   */
  findActiveByUserId(userId: string): Promise<Result<UserSession[], RepositoryError>>;

  /**
   * Update session last accessed time
   */
  updateLastAccessed(sessionId: string): Promise<Result<void, RepositoryError>>;

  /**
   * Deactivate session
   */
  deactivate(sessionId: string): Promise<Result<void, RepositoryError>>;

  /**
   * Deactivate all sessions for a user
   */
  deactivateAllForUser(userId: string): Promise<Result<void, RepositoryError>>;

  /**
   * Clean up expired sessions
   */
  cleanupExpired(): Promise<Result<number, RepositoryError>>;

  /**
   * Get session statistics for a user
   */
  getSessionStats(userId: string): Promise<Result<SessionStats, RepositoryError>>;
}

/**
 * User session data
 */
export interface UserSession {
  id: string;
  userId: string;
  tokenHash: string;
  deviceId?: string;
  deviceType?: DeviceType;
  deviceName?: string;
  ipAddress?: string;
  userAgent?: string;
  isActive: boolean;
  expiresAt: Date;
  createdAt: Date;
  lastAccessedAt: Date;
}

/**
 * Device types
 */
export enum DeviceType {
  MOBILE = 'mobile',
  WEB = 'web',
  TABLET = 'tablet',
  DESKTOP = 'desktop'
}

/**
 * Session statistics
 */
export interface SessionStats {
  totalSessions: number;
  activeSessions: number;
  deviceBreakdown: Record<DeviceType, number>;
  lastLogin: Date | null;
  averageSessionDuration: number; // in minutes
}

/**
 * Session creation parameters
 */
export interface CreateSessionParams {
  userId: string;
  deviceId?: string;
  deviceType?: DeviceType;
  deviceName?: string;
  ipAddress?: string;
  userAgent?: string;
  expiresAt: Date;
}

/**
 * Session validation result
 */
export interface SessionValidation {
  isValid: boolean;
  session?: UserSession;
  reason?: SessionInvalidReason;
}

/**
 * Reasons why a session might be invalid
 */
export enum SessionInvalidReason {
  NOT_FOUND = 'not_found',
  EXPIRED = 'expired',
  INACTIVE = 'inactive',
  REVOKED = 'revoked'
}
