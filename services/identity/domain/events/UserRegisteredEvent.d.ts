import { BaseDomainEvent } from '@thankful/shared';
import { UserId, UserRole } from '@thankful/shared';
/**
 * Domain event emitted when a new user registers
 */
export declare class UserRegisteredEvent extends BaseDomainEvent {
    constructor(userId: UserId, data: {
        email: string;
        phone: string;
        profile: {
            firstName: string;
            lastName: string;
            preferences: unknown;
        };
        role: UserRole;
    });
}
