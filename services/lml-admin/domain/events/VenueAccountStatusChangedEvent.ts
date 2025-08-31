import { BaseDomainEvent } from '@thankful/shared';

/**
 * Domain event fired when a venue account status changes
 */
export class VenueAccountStatusChangedEvent extends BaseDomainEvent {
  public readonly eventName = 'VenueAccountStatusChanged';
  
  constructor(
    aggregateId: string,
    public readonly data: VenueAccountStatusChangedEventData
  ) {
    super(aggregateId);
  }
}

export interface VenueAccountStatusChangedEventData {
  venueId: string;
  previousStatus: string;
  newStatus: string;
  changedBy: string;
  changedAt: Date;
  reason: string;
}

