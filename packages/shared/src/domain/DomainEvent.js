/**
 * Base implementation of DomainEvent
 */
export class BaseDomainEvent {
    aggregateId;
    eventType;
    data;
    id;
    occurredOn;
    version = 1;
    constructor(aggregateId, eventType, data = {}) {
        this.aggregateId = aggregateId;
        this.eventType = eventType;
        this.data = data;
        this.id = crypto.randomUUID();
        this.occurredOn = new Date();
    }
}
