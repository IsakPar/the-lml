import { Entity } from './Entity.js';
import { DomainEvent } from './DomainEvent.js';

/**
 * Aggregate Root base class for DDD aggregates
 * Manages domain events and enforces aggregate boundaries
 */
export abstract class AggregateRoot<TId> extends Entity<TId> {
  private _domainEvents: DomainEvent[] = [];

  protected addDomainEvent(event: DomainEvent): void {
    this._domainEvents.push(event);
  }

  public clearDomainEvents(): void {
    this._domainEvents = [];
  }

  public getDomainEvents(): DomainEvent[] {
    return [...this._domainEvents];
  }

  public markEventsAsDispatched(): void {
    this._domainEvents = [];
  }
}
