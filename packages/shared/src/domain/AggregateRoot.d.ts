import { Entity } from './Entity.js';
import { DomainEvent } from './DomainEvent.js';
/**
 * Aggregate Root base class for DDD aggregates
 * Manages domain events and enforces aggregate boundaries
 */
export declare abstract class AggregateRoot<TId> extends Entity<TId> {
    private _domainEvents;
    protected addDomainEvent(event: DomainEvent): void;
    clearDomainEvents(): void;
    getDomainEvents(): DomainEvent[];
    markEventsAsDispatched(): void;
}
