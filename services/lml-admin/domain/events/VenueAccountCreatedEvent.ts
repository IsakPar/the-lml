import { BaseDomainEvent } from '@thankful/shared';

/**
 * Domain event fired when a new venue account is created
 */
export class VenueAccountCreatedEvent extends BaseDomainEvent {
  public readonly eventName = 'VenueAccountCreated';
  
  constructor(
    aggregateId: string,
    public readonly data: VenueAccountCreatedEventData
  ) {
    super(aggregateId);
  }
}

export interface VenueAccountCreatedEventData {
  venueName: string;
  venueSlug: string;
  displayName: string;
  status: string;
  createdBy: string;
  createdAt: Date;
}

