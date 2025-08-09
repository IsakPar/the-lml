import { Entity } from '@thankful/shared';
import { Coordinate } from '@thankful/shared';
import { VenueCapacity } from '../valueobjects/VenueCapacity.js';
import { SeatLayout } from '../valueobjects/SeatLayout.js';

/**
 * VenueSection entity representing a section within a venue
 * Contains seats and layout information for mobile rendering
 */
export class VenueSection extends Entity<string> {
  private constructor(
    id: string,
    private readonly _name: string,
    private readonly _capacity: VenueCapacity,
    private readonly _seatLayout: SeatLayout,
    private readonly _position: Coordinate,
    private readonly _createdAt: Date
  ) {
    super(id);
  }

  public static create(
    id: string,
    name: string,
    capacity: VenueCapacity,
    seatLayout: SeatLayout,
    position: Coordinate
  ): VenueSection {
    if (!name.trim()) {
      throw new Error('Section name cannot be empty');
    }

    if (name.length > 100) {
      throw new Error('Section name must be 100 characters or less');
    }

    return new VenueSection(
      id,
      name.trim(),
      capacity,
      seatLayout,
      position,
      new Date()
    );
  }

  // Getters
  public get name(): string {
    return this._name;
  }

  public get capacity(): VenueCapacity {
    return this._capacity;
  }

  public get seatLayout(): SeatLayout {
    return this._seatLayout;
  }

  public get position(): Coordinate {
    return this._position;
  }

  public get createdAt(): Date {
    return this._createdAt;
  }

  // Business methods
  public getSeatCount(): number {
    return this._seatLayout.getSeatCount();
  }

  public getSeatsByRow(): Map<string, number> {
    return this._seatLayout.getSeatsByRow();
  }

  public validateCapacityMatches(): boolean {
    return this._capacity.value === this._seatLayout.getSeatCount();
  }
}
