import { ValueObject, Result } from '@thankful/shared';

interface PhoneNumberProps {
  value: string;
  countryCode: string;
}

/**
 * PhoneNumber value object with international format validation
 */
export class PhoneNumber extends ValueObject<PhoneNumberProps> {
  private constructor(props: PhoneNumberProps) {
    super(props);
  }

  public static create(phoneNumber: string, countryCode: string = '+1'): Result<PhoneNumber, string> {
    const cleanPhone = this.cleanPhoneNumber(phoneNumber);
    
    if (!this.isValidPhoneNumber(cleanPhone)) {
      return Result.failure('Invalid phone number format');
    }
    
    return Result.success(new PhoneNumber({ 
      value: cleanPhone, 
      countryCode 
    }));
  }

  private static cleanPhoneNumber(phone: string): string {
    return phone.replace(/[^\d+]/g, '');
  }

  private static isValidPhoneNumber(phone: string): boolean {
    // Basic validation - should be enhanced with proper international validation
    return /^\+?[\d]{10,15}$/.test(phone);
  }

  public get value(): string {
    return this.props.value;
  }

  public getCountryCode(): string {
    return this.props.countryCode;
  }

  public getInternationalFormat(): string {
    return `${this.props.countryCode}${this.props.value}`;
  }
}
