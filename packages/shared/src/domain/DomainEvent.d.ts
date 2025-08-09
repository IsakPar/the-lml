/**
 * Base DomainEvent for event-driven communication between bounded contexts
 */
export interface DomainEvent {
    readonly id: string;
    readonly aggregateId: string;
    readonly eventType: string;
    readonly occurredOn: Date;
    readonly version: number;
    readonly data: Record<string, unknown>;
}
/**
 * Base implementation of DomainEvent
 */
export declare abstract class BaseDomainEvent implements DomainEvent {
    readonly aggregateId: string;
    readonly eventType: string;
    readonly data: Record<string, unknown>;
    readonly id: string;
    readonly occurredOn: Date;
    readonly version: number;
    protected constructor(aggregateId: string, eventType: string, data?: Record<string, unknown>);
}
