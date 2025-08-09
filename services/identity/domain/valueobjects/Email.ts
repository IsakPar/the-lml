import { ValueObject, Result } from '@thankful/shared';

interface EmailProps {
  value: string;
}

/**
 * Email value object with validation
 */
export class Email extends ValueObject<EmailProps> {
  private constructor(props: EmailProps) {
    super(props);
  }

  public static create(email: string): Result<Email, string> {
    if (!this.isValidEmail(email)) {
      return Result.failure('Invalid email format');
    }
    
    return Result.success(new Email({ value: email.toLowerCase() }));
  }

  private static isValidEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email) && email.length <= 254;
  }

  public get value(): string {
    return this.props.value;
  }

  public getDomain(): string {
    return this.props.value.split('@')[1];
  }
}
