import { Result } from '@thankful/shared';

/**
 * Password Service Port
 * Handles password hashing, validation, and security
 */
export interface PasswordService {
  /**
   * Hash a password securely
   */
  hash(password: string): Promise<Result<string, PasswordError>>;

  /**
   * Verify a password against its hash
   */
  verify(password: string, hash: string): Promise<Result<boolean, PasswordError>>;

  /**
   * Validate password strength
   */
  validateStrength(password: string): Result<PasswordStrength, PasswordError>;

  /**
   * Generate a secure random password
   */
  generateSecure(length?: number): string;

  /**
   * Check if password needs rehashing (for security upgrades)
   */
  needsRehash(hash: string): boolean;
}

/**
 * Password strength assessment
 */
export interface PasswordStrength {
  score: number; // 0-4 (0 = very weak, 4 = very strong)
  isValid: boolean;
  feedback: string[];
  suggestions: string[];
  estimatedCrackTime: string;
}

/**
 * Password requirements
 */
export interface PasswordRequirements {
  minLength: number;
  maxLength: number;
  requireUppercase: boolean;
  requireLowercase: boolean;
  requireNumbers: boolean;
  requireSpecialChars: boolean;
  preventCommonPasswords: boolean;
  preventPersonalInfo: boolean;
}

/**
 * Password error types
 */
export interface PasswordError {
  type: 'WEAK_PASSWORD' | 'INVALID_FORMAT' | 'HASHING_FAILED' | 'VERIFICATION_FAILED';
  message: string;
  requirements?: PasswordRequirements;
  violations?: string[];
}

/**
 * Helper to create password errors
 */
export const PasswordError = {
  weakPassword: (violations: string[], requirements: PasswordRequirements): PasswordError => ({
    type: 'WEAK_PASSWORD',
    message: 'Password does not meet security requirements',
    requirements,
    violations,
  }),

  invalidFormat: (message: string): PasswordError => ({
    type: 'INVALID_FORMAT',
    message,
  }),

  hashingFailed: (message: string): PasswordError => ({
    type: 'HASHING_FAILED',
    message,
  }),

  verificationFailed: (message: string): PasswordError => ({
    type: 'VERIFICATION_FAILED',
    message,
  }),
};

/**
 * Default password requirements
 */
export const DEFAULT_PASSWORD_REQUIREMENTS: PasswordRequirements = {
  minLength: 8,
  maxLength: 128,
  requireUppercase: true,
  requireLowercase: true,
  requireNumbers: true,
  requireSpecialChars: true,
  preventCommonPasswords: true,
  preventPersonalInfo: true,
};
