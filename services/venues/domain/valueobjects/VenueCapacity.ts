import { ValueObject } from '@thankful/shared';

interface VenueCapacityProps {
  value: number;
}

/**
 * VenueCapacity value object with validation
 */
export class VenueCapacity extends ValueObject<VenueCapacityProps> {
  private constructor(props: VenueCapacityProps) {
    super(props);
  }

  public static create(capacity: number): VenueCapacity {
    if (!Number.isInteger(capacity) || capacity <= 0) {
      throw new Error('Venue capacity must be a positive integer');
    }

    if (capacity > 1000000) {
      throw new Error('Venue capacity cannot exceed 1,000,000');
    }

    return new VenueCapacity({ value: capacity });
  }

  public get value(): number {
    return this.props.value;
  }

  public isLargeVenue(): boolean {
    return this.props.value >= 10000;
  }

  public isMediumVenue(): boolean {
    return this.props.value >= 1000 && this.props.value < 10000;
  }

  public isSmallVenue(): boolean {
    return this.props.value < 1000;
  }

  public getVenueSize(): 'small' | 'medium' | 'large' {
    if (this.isSmallVenue()) return 'small';
    if (this.isMediumVenue()) return 'medium';
    return 'large';
  }
}
