import { AggregateRoot, Result } from '@thankful/shared';
import { UserId, UserRole } from '@thankful/shared';
import { Email } from '../valueobjects/Email.js';
import { PhoneNumber } from '../valueobjects/PhoneNumber.js';
import { UserProfile } from '../valueobjects/UserProfile.js';
import { UserRegisteredEvent } from '../events/UserRegisteredEvent.js';

/**
 * User aggregate root for Identity bounded context
 * Manages user authentication and profile data
 */
export class User extends AggregateRoot<UserId> {
  private constructor(
    id: UserId,
    private readonly _email: Email,
    private readonly _phone: PhoneNumber | undefined,
    private readonly _profile: UserProfile,
    private readonly _role: UserRole,
    private readonly _isEmailVerified: boolean,
    private readonly _isPhoneVerified: boolean,
    private readonly _createdAt: Date,
    private readonly _passwordHash?: string
  ) {
    super(id);
  }

  public static create(
    id: string,
    email: Email,
    phone: PhoneNumber | undefined,
    profile: UserProfile,
    role: UserRole = UserRole.USER,
    passwordHash?: string
  ): Result<User, string> {
    const user = new User(
      id,
      email,
      phone,
      profile,
      role,
      false, // email not verified initially
      false, // phone not verified initially
      new Date(),
      passwordHash
    );

    // Emit domain event for registration
    user.addDomainEvent(new UserRegisteredEvent(id, {
      email: email.value,
      phone: phone?.value || '',
      profile: profile.value,
      role
    }));

    return Result.success(user);
  }

  // Getters
  public get email(): Email {
    return this._email;
  }

  public get phone(): PhoneNumber | undefined {
    return this._phone;
  }

  public get profile(): UserProfile {
    return this._profile;
  }

  public get role(): UserRole {
    return this._role;
  }

  public get isEmailVerified(): boolean {
    return this._isEmailVerified;
  }

  public get isPhoneVerified(): boolean {
    return this._isPhoneVerified;
  }

  public get createdAt(): Date {
    return this._createdAt;
  }

  // Business methods
  public canAccessAdminFeatures(): boolean {
    return this._role === UserRole.ORGANIZER_ADMIN || 
           this._role === UserRole.SUPPORT || 
           this._role === UserRole.SUPER_ADMIN;
  }

  public canManageEvents(): boolean {
    return this._role === UserRole.ORGANIZER_ADMIN || 
           this._role === UserRole.SUPER_ADMIN;
  }

  // Additional methods for application layer compatibility
  public getId(): string {
    return this.id;
  }

  public getEmail(): Email {
    return this._email;
  }

  public getPhone(): PhoneNumber | undefined {
    return this._phone;
  }

  public getProfile(): UserProfile {
    return this._profile;
  }

  public getRole(): string {
    return this._role;
  }

  public getPasswordHash(): string | undefined {
    return this._passwordHash;
  }

  public getCreatedAt(): Date {
    return this.createdAt;
  }

  public isActive(): boolean {
    return true; // Simplified for now
  }
}
