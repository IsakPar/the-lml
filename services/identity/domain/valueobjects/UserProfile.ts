import { ValueObject, Result } from '@thankful/shared';

interface UserProfileProps {
  firstName: string;
  lastName: string;
  dateOfBirth?: Date;
  avatarUrl?: string;
  preferences: {
    notifications: {
      email: boolean;
      sms: boolean;
      push: boolean;
    };
    timezone: string;
    language: string;
  };
}

/**
 * UserProfile value object containing user's personal information and preferences
 */
export class UserProfile extends ValueObject<UserProfileProps> {
  private constructor(props: UserProfileProps) {
    super(props);
  }

  public static create(props: {
    firstName: string;
    lastName: string;
    dateOfBirth?: Date;
    avatarUrl?: string;
    preferences?: {
      notifications?: {
        email?: boolean;
        sms?: boolean;
        push?: boolean;
      };
      timezone?: string;
      language?: string;
    };
  }): Result<UserProfile, string> {
    if (!props.firstName?.trim() || !props.lastName?.trim()) {
      return Result.failure('First name and last name are required');
    }

    if (props.firstName.length > 50 || props.lastName.length > 50) {
      return Result.failure('Names must be 50 characters or less');
    }

    return Result.success(new UserProfile({
      firstName: props.firstName.trim(),
      lastName: props.lastName.trim(),
      dateOfBirth: props.dateOfBirth,
      avatarUrl: props.avatarUrl,
      preferences: {
        notifications: {
          email: props.preferences?.notifications?.email ?? true,
          sms: props.preferences?.notifications?.sms ?? true,
          push: props.preferences?.notifications?.push ?? true
        },
        timezone: props.preferences?.timezone || 'UTC',
        language: props.preferences?.language || 'en'
      }
    }));
  }

  public get value(): UserProfileProps {
    return this.props;
  }

  public getFullName(): string {
    return `${this.props.firstName} ${this.props.lastName}`;
  }

  public getInitials(): string {
    return `${this.props.firstName.charAt(0)}${this.props.lastName.charAt(0)}`.toUpperCase();
  }

  public isAdult(): boolean {
    if (!this.props.dateOfBirth) {
      return false; // Cannot determine age
    }
    
    const today = new Date();
    const age = today.getFullYear() - this.props.dateOfBirth.getFullYear();
    const monthDiff = today.getMonth() - this.props.dateOfBirth.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < this.props.dateOfBirth.getDate())) {
      return age - 1 >= 18;
    }
    
    return age >= 18;
  }
}
