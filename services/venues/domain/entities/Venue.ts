import { AggregateRoot } from '@thankful/shared';
import { VenueId, Address, Coordinate } from '@thankful/shared';
import { VenueName } from '../valueobjects/VenueName.js';
import { VenueCapacity } from '../valueobjects/VenueCapacity.js';
import { VenueSection } from './VenueSection.js';

/**
 * Venue aggregate root for Venues bounded context
 * Manages venue information and section organization
 */
export class Venue extends AggregateRoot<VenueId> {
  private constructor(
    id: VenueId,
    private readonly _name: VenueName,
    private readonly _address: Address,
    private readonly _capacity: VenueCapacity,
    private readonly _sections: Map<string, VenueSection>,
    private readonly _createdAt: Date
  ) {
    super(id);
  }

  public static create(
    id: VenueId,
    name: VenueName,
    address: Address,
    capacity: VenueCapacity
  ): Venue {
    return new Venue(
      id,
      name,
      address,
      capacity,
      new Map(),
      new Date()
    );
  }

  // Getters
  public get name(): VenueName {
    return this._name;
  }

  public get address(): Address {
    return this._address;
  }

  public get capacity(): VenueCapacity {
    return this._capacity;
  }

  public get sections(): VenueSection[] {
    return Array.from(this._sections.values());
  }

  public get createdAt(): Date {
    return this._createdAt;
  }

  // Business methods
  public addSection(section: VenueSection): void {
    if (this._sections.has(section.id)) {
      throw new Error(`Section ${section.id} already exists`);
    }

    const totalCapacityAfterAdd = this.getTotalSectionCapacity() + section.capacity.value;
    if (totalCapacityAfterAdd > this._capacity.value) {
      throw new Error('Adding section would exceed venue capacity');
    }

    this._sections.set(section.id, section);
  }

  public removeSection(sectionId: string): void {
    if (!this._sections.has(sectionId)) {
      throw new Error(`Section ${sectionId} does not exist`);
    }

    this._sections.delete(sectionId);
  }

  public getSection(sectionId: string): VenueSection | undefined {
    return this._sections.get(sectionId);
  }

  public getTotalSectionCapacity(): number {
    return Array.from(this._sections.values())
      .reduce((total, section) => total + section.capacity.value, 0);
  }

  public getAvailableCapacity(): number {
    return this._capacity.value - this.getTotalSectionCapacity();
  }
}
