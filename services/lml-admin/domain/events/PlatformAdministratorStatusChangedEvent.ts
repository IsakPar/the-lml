import { BaseDomainEvent } from '@thankful/shared';

/**
 * Domain event fired when a platform administrator status changes
 */
export class PlatformAdministratorStatusChangedEvent extends BaseDomainEvent {
  public readonly eventName = 'PlatformAdministratorStatusChanged';
  
  constructor(
    aggregateId: string,
    public readonly data: PlatformAdministratorStatusChangedEventData
  ) {
    super(aggregateId);
  }
}

export interface PlatformAdministratorStatusChangedEventData {
  userId: string;
  previousRole: string;
  newRole: string;
  changedBy: string;
  changedAt: Date;
  reason: string;
}

