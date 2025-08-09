import { Entity } from './Entity.js';
/**
 * Aggregate Root base class for DDD aggregates
 * Manages domain events and enforces aggregate boundaries
 */
export class AggregateRoot extends Entity {
    _domainEvents = [];
    addDomainEvent(event) {
        this._domainEvents.push(event);
    }
    clearDomainEvents() {
        this._domainEvents = [];
    }
    getDomainEvents() {
        return [...this._domainEvents];
    }
    markEventsAsDispatched() {
        this._domainEvents = [];
    }
}
