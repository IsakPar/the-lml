import { ValueObject } from '@thankful/shared';

interface VenueNameProps {
  value: string;
}

/**
 * VenueName value object with validation
 */
export class VenueName extends ValueObject<VenueNameProps> {
  private constructor(props: VenueNameProps) {
    super(props);
  }

  public static create(name: string): VenueName {
    if (!name.trim()) {
      throw new Error('Venue name cannot be empty');
    }

    if (name.length > 200) {
      throw new Error('Venue name must be 200 characters or less');
    }

    return new VenueName({ value: name.trim() });
  }

  public get value(): string {
    return this.props.value;
  }

  public getSlug(): string {
    return this.props.value
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .trim();
  }
}
