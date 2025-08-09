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
export abstract class BaseDomainEvent implements DomainEvent {
  public readonly id: string;
  public readonly occurredOn: Date;
  public readonly version: number = 1;

  protected constructor(
    public readonly aggregateId: string,
    public readonly eventType: string,
    public readonly data: Record<string, unknown> = {}
  ) {
    this.id = crypto.randomUUID();
    this.occurredOn = new Date();
  }
}
