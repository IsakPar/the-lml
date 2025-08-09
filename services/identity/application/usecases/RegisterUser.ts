import { Result, UserId, UserRole } from '@thankful/shared';
import { randomUUID } from 'crypto';
import { UserRepository, RepositoryError } from '../ports/UserRepository.js';
import { PasswordService } from '../ports/PasswordService.js';
import { User } from '../../domain/entities/User.js';
import { Email } from '../../domain/valueobjects/Email.js';
import { PhoneNumber } from '../../domain/valueobjects/PhoneNumber.js';
import { UserProfile } from '../../domain/valueobjects/UserProfile.js';
import { UserRegisteredEvent } from '../../domain/events/UserRegisteredEvent.js';

/**
 * Register User Use Case
 * Handles new user registration with validation
 */
export class RegisterUser {
  constructor(
    private userRepository: UserRepository,
    private passwordService: PasswordService
  ) {}

  /**
   * Execute user registration
   */
  async execute(command: RegisterUserCommand): Promise<Result<UserRegistrationResult, RegistrationError>> {
    // Validate email format
    const emailResult = Email.create(command.email);
    if (emailResult.isFailure) {
      return Result.failure(RegistrationError.validationError('Invalid email format', ['email']));
    }

    // Validate phone if provided
    let phoneNumber: PhoneNumber | undefined;
    if (command.phone) {
      const phoneResult = PhoneNumber.create(command.phone);
      if (phoneResult.isFailure) {
        return Result.failure(RegistrationError.validationError('Invalid phone number format', ['phone']));
      }
      phoneNumber = phoneResult.value;
    }

    // Validate password strength
    const passwordStrength = this.passwordService.validateStrength(command.password);
    if (passwordStrength.isFailure || !passwordStrength.value.isValid) {
      return Result.failure(RegistrationError.weakPassword(
        'Password does not meet security requirements',
        passwordStrength.isSuccess ? passwordStrength.value.feedback : ['Password is too weak']
      ));
    }

    // Check if email already exists
    const emailExistsResult = await this.userRepository.emailExists(emailResult.value);
    if (emailExistsResult.isFailure) {
      return Result.failure(RegistrationError.repositoryError(emailExistsResult.error.message));
    }
    if (emailExistsResult.value) {
      return Result.failure(RegistrationError.emailAlreadyExists('An account with this email already exists'));
    }

    // Check if phone already exists (if provided)
    if (phoneNumber) {
      const phoneExistsResult = await this.userRepository.phoneExists(phoneNumber);
      if (phoneExistsResult.isFailure) {
        return Result.failure(RegistrationError.repositoryError(phoneExistsResult.error.message));
      }
      if (phoneExistsResult.value) {
        return Result.failure(RegistrationError.phoneAlreadyExists('An account with this phone number already exists'));
      }
    }

    // Hash password
    const passwordHashResult = await this.passwordService.hash(command.password);
    if (passwordHashResult.isFailure) {
      return Result.failure(RegistrationError.passwordHashingFailed('Failed to secure password'));
    }

    // Create user profile
    const profileResult = UserProfile.create({
      firstName: command.firstName,
      lastName: command.lastName,
      dateOfBirth: command.dateOfBirth,
      preferences: command.preferences || {
        notifications: {
          email: true,
          sms: true,
          push: true,
        },
        timezone: 'UTC',
        language: 'en',
      },
    });

    if (profileResult.isFailure) {
      return Result.failure(RegistrationError.validationError('Invalid profile data', ['profile']));
    }

    // Create user entity  
    const userId = randomUUID(); // Generate UUID for user ID
    const userResult = User.create(
      userId,
      emailResult.value,
      phoneNumber,
      profileResult.value,
      (command.role as UserRole) || UserRole.USER,
      passwordHashResult.value
    );

    if (userResult.isFailure) {
      return Result.failure(RegistrationError.validationError('Failed to create user', ['user']));
    }

    const user = userResult.value;

    // Save user to repository
    const saveResult = await this.userRepository.save(user);
    if (saveResult.isFailure) {
      // Handle specific constraint violations
      if (saveResult.error.type === 'CONSTRAINT_VIOLATION') {
        if (saveResult.error.code === 'users_email_unique') {
          return Result.failure(RegistrationError.emailAlreadyExists('Email address is already registered'));
        }
        if (saveResult.error.code === 'users_phone_unique') {
          return Result.failure(RegistrationError.phoneAlreadyExists('Phone number is already registered'));
        }
      }
      return Result.failure(RegistrationError.repositoryError(saveResult.error.message));
    }

    const savedUser = saveResult.value;

    // Emit domain event
    // Domain events are already added in User.create(), no need to add again
    // const registrationEvent = new UserRegisteredEvent(savedUser.getId(), {
    //   email: savedUser.getEmail().value,
    //   firstName: savedUser.getProfile().value.firstName,
    //   lastName: savedUser.getProfile().value.lastName,
    //   phone: savedUser.getPhone()?.value,
    //   registeredAt: new Date(),
    // });

    // Return registration result
    const result: UserRegistrationResult = {
      userId: savedUser.getId(),
      email: savedUser.getEmail().value,
      firstName: savedUser.getProfile().value.firstName,
      lastName: savedUser.getProfile().value.lastName,
      role: savedUser.getRole(),
      isEmailVerified: savedUser.isEmailVerified,
      isPhoneVerified: savedUser.isPhoneVerified,
      createdAt: savedUser.getCreatedAt(),
      requiresEmailVerification: !savedUser.isEmailVerified,
      requiresPhoneVerification: !!phoneNumber && !savedUser.isPhoneVerified,
    };

    return Result.success(result);
  }
}

/**
 * Registration command
 */
export interface RegisterUserCommand {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone?: string;
  dateOfBirth?: Date;
  role?: string;
  preferences?: Record<string, any>;
  acceptTerms: boolean;
  acceptPrivacyPolicy: boolean;
}

/**
 * Registration result
 */
export interface UserRegistrationResult {
  userId: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  isEmailVerified: boolean;
  isPhoneVerified: boolean;
  createdAt: Date;
  requiresEmailVerification: boolean;
  requiresPhoneVerification: boolean;
}

/**
 * Registration error types
 */
export interface RegistrationError {
  type: 'VALIDATION_ERROR' | 'EMAIL_ALREADY_EXISTS' | 'PHONE_ALREADY_EXISTS' | 'WEAK_PASSWORD' | 'PASSWORD_HASHING_FAILED' | 'REPOSITORY_ERROR';
  message: string;
  fields?: string[];
  details?: string[];
}

/**
 * Helper to create registration errors
 */
export const RegistrationError = {
  validationError: (message: string, fields: string[]): RegistrationError => ({
    type: 'VALIDATION_ERROR',
    message,
    fields,
  }),

  emailAlreadyExists: (message: string): RegistrationError => ({
    type: 'EMAIL_ALREADY_EXISTS',
    message,
  }),

  phoneAlreadyExists: (message: string): RegistrationError => ({
    type: 'PHONE_ALREADY_EXISTS',
    message,
  }),

  weakPassword: (message: string, details: string[]): RegistrationError => ({
    type: 'WEAK_PASSWORD',
    message,
    details,
  }),

  passwordHashingFailed: (message: string): RegistrationError => ({
    type: 'PASSWORD_HASHING_FAILED',
    message,
  }),

  repositoryError: (message: string): RegistrationError => ({
    type: 'REPOSITORY_ERROR',
    message,
  }),
};
