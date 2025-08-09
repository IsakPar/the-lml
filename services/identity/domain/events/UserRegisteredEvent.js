import { BaseDomainEvent } from '@thankful/shared';
/**
 * Domain event emitted when a new user registers
 */
export class UserRegisteredEvent extends BaseDomainEvent {
    constructor(userId, data) {
        super(userId, 'UserRegistered', data);
    }
}
