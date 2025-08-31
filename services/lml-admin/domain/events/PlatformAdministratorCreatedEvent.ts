import { BaseDomainEvent } from '@thankful/shared';
import { AdminPermissionsData } from '../valueobjects/AdminRole.js';

/**
 * Domain event fired when a new platform administrator is created
 */
export class PlatformAdministratorCreatedEvent extends BaseDomainEvent {
  public readonly eventName = 'PlatformAdministratorCreated';
  
  constructor(
    aggregateId: string,
    public readonly data: PlatformAdministratorCreatedEventData
  ) {
    super(aggregateId);
  }
}

export interface PlatformAdministratorCreatedEventData {
  userId: string;
  role: string;
  permissions: AdminPermissionsData;
  createdBy?: string;
  createdAt: Date;
}

