import { DomainEvent } from '@thankful/shared';

/**
 * Domain Event Bus
 * Coordinates event publishing and subscription across bounded contexts
 */
export class DomainEventBus {
  private handlers = new Map<string, EventHandler[]>();
  private middleware: EventMiddleware[] = [];

  /**
   * Register an event handler
   */
  subscribe<T extends DomainEvent>(
    eventType: string,
    handler: EventHandler<T>
  ): void {
    if (!this.handlers.has(eventType)) {
      this.handlers.set(eventType, []);
    }
    
    this.handlers.get(eventType)!.push(handler as EventHandler);
  }

  /**
   * Unsubscribe an event handler
   */
  unsubscribe<T extends DomainEvent>(
    eventType: string,
    handler: EventHandler<T>
  ): void {
    const handlers = this.handlers.get(eventType);
    if (handlers) {
      const index = handlers.indexOf(handler as EventHandler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    }
  }

  /**
   * Publish an event to all subscribers
   */
  async publish(event: DomainEvent): Promise<void> {
    // Apply middleware in order
    let processedEvent = event;
    for (const middleware of this.middleware) {
      processedEvent = await middleware.beforePublish(processedEvent);
    }

    const handlers = this.handlers.get(event.eventType) || [];
    
    // Execute handlers concurrently but capture all errors
    const results = await Promise.allSettled(
      handlers.map(handler => this.executeHandler(handler, processedEvent))
    );

    // Log any handler failures
    const failures = results
      .filter((result): result is PromiseRejectedResult => result.status === 'rejected')
      .map(result => result.reason);

    if (failures.length > 0) {
      console.error(`Event handling failures for ${event.eventType}:`, failures);
      
      // Apply error middleware
      for (const middleware of this.middleware) {
        await middleware.onError?.(event, failures);
      }
    }

    // Apply post-publish middleware
    for (const middleware of this.middleware) {
      await middleware.afterPublish?.(processedEvent, results);
    }
  }

  /**
   * Publish multiple events in batch
   */
  async publishBatch(events: DomainEvent[]): Promise<void> {
    await Promise.all(events.map(event => this.publish(event)));
  }

  /**
   * Add middleware to the event bus
   */
  use(middleware: EventMiddleware): void {
    this.middleware.push(middleware);
  }

  /**
   * Get all registered event types
   */
  getRegisteredEventTypes(): string[] {
    return Array.from(this.handlers.keys());
  }

  /**
   * Get handler count for an event type
   */
  getHandlerCount(eventType: string): number {
    return this.handlers.get(eventType)?.length || 0;
  }

  /**
   * Clear all handlers (useful for testing)
   */
  clear(): void {
    this.handlers.clear();
  }

  /**
   * Execute a single handler with error isolation
   */
  private async executeHandler(handler: EventHandler, event: DomainEvent): Promise<void> {
    try {
      await handler.handle(event);
    } catch (error) {
      // Log error but don't let it affect other handlers
      console.error(`Handler failed for ${event.eventType}:`, error);
      throw error; // Re-throw so Promise.allSettled captures it
    }
  }
}

/**
 * Event handler interface
 */
export interface EventHandler<T extends DomainEvent = DomainEvent> {
  handle(event: T): Promise<void>;
}

/**
 * Event middleware interface
 */
export interface EventMiddleware {
  beforePublish(event: DomainEvent): Promise<DomainEvent>;
  afterPublish?(event: DomainEvent, results: PromiseSettledResult<void>[]): Promise<void>;
  onError?(event: DomainEvent, errors: any[]): Promise<void>;
}

/**
 * Built-in middleware implementations
 */

/**
 * Logging middleware
 */
export class LoggingMiddleware implements EventMiddleware {
  async beforePublish(event: DomainEvent): Promise<DomainEvent> {
    console.log(`📡 Publishing event: ${event.eventType}`, {
      eventId: event.id,
      aggregateId: event.aggregateId,
      occurredAt: event.occurredOn,
    });
    return event;
  }

  async afterPublish(event: DomainEvent, results: PromiseSettledResult<void>[]): Promise<void> {
    const successCount = results.filter(r => r.status === 'fulfilled').length;
    const failureCount = results.filter(r => r.status === 'rejected').length;
    
    console.log(`✅ Event ${event.eventType} processed: ${successCount} success, ${failureCount} failures`);
  }

  async onError(event: DomainEvent, errors: any[]): Promise<void> {
    console.error(`❌ Event ${event.eventType} had ${errors.length} handler failures`);
  }
}

/**
 * Metrics middleware
 */
export class MetricsMiddleware implements EventMiddleware {
  private metrics: EventMetrics;

  constructor(metrics: EventMetrics) {
    this.metrics = metrics;
  }

  async beforePublish(event: DomainEvent): Promise<DomainEvent> {
    this.metrics.incrementEventPublished(event.eventType);
    return event;
  }

  async afterPublish(event: DomainEvent, results: PromiseSettledResult<void>[]): Promise<void> {
    const successCount = results.filter(r => r.status === 'fulfilled').length;
    const failureCount = results.filter(r => r.status === 'rejected').length;
    
    this.metrics.recordEventHandling(event.eventType, successCount, failureCount);
  }
}

/**
 * Event metrics interface
 */
export interface EventMetrics {
  incrementEventPublished(eventType: string): void;
  recordEventHandling(eventType: string, successCount: number, failureCount: number): void;
}

/**
 * Persistence middleware (for event sourcing)
 */
export class PersistenceMiddleware implements EventMiddleware {
  private eventStore: EventStore;

  constructor(eventStore: EventStore) {
    this.eventStore = eventStore;
  }

  async beforePublish(event: DomainEvent): Promise<DomainEvent> {
    // Store event before publishing to handlers
    await this.eventStore.saveEvent(event);
    return event;
  }
}

/**
 * Event store interface
 */
export interface EventStore {
  saveEvent(event: DomainEvent): Promise<void>;
  getEvents(aggregateId: string): Promise<DomainEvent[]>;
  getEventsSince(timestamp: Date): Promise<DomainEvent[]>;
}

/**
 * Retry middleware for failed handlers
 */
export class RetryMiddleware implements EventMiddleware {
  private retryQueue: RetryableEvent[] = [];
  private maxRetries: number;
  private retryDelay: number;

  constructor(maxRetries = 3, retryDelay = 1000) {
    this.maxRetries = maxRetries;
    this.retryDelay = retryDelay;
  }

  async beforePublish(event: DomainEvent): Promise<DomainEvent> {
    return event;
  }

  async onError(event: DomainEvent, errors: any[]): Promise<void> {
    // Queue failed event for retry
    this.retryQueue.push({
      event,
      retryCount: 0,
      lastError: errors[0],
      nextRetryAt: new Date(Date.now() + this.retryDelay),
    });
  }

  /**
   * Process retry queue
   */
  async processRetries(eventBus: DomainEventBus): Promise<void> {
    const now = new Date();
    const readyToRetry = this.retryQueue.filter(item => item.nextRetryAt <= now);

    for (const item of readyToRetry) {
      if (item.retryCount < this.maxRetries) {
        try {
          await eventBus.publish(item.event);
          // Remove from retry queue on success
          this.removeFromRetryQueue(item);
        } catch (error) {
          // Update retry info
          item.retryCount++;
          item.lastError = error;
          item.nextRetryAt = new Date(Date.now() + this.retryDelay * Math.pow(2, item.retryCount)); // Exponential backoff
        }
      } else {
        // Max retries reached, move to dead letter queue
        console.error(`Event ${item.event.eventType} failed after ${this.maxRetries} retries:`, item.lastError);
        this.removeFromRetryQueue(item);
      }
    }
  }

  private removeFromRetryQueue(item: RetryableEvent): void {
    const index = this.retryQueue.indexOf(item);
    if (index > -1) {
      this.retryQueue.splice(index, 1);
    }
  }
}

/**
 * Retryable event info
 */
interface RetryableEvent {
  event: DomainEvent;
  retryCount: number;
  lastError: any;
  nextRetryAt: Date;
}

/**
 * Singleton event bus instance
 */
let eventBusInstance: DomainEventBus | null = null;

export function getEventBus(): DomainEventBus {
  if (!eventBusInstance) {
    eventBusInstance = new DomainEventBus();
    
    // Add default middleware
    eventBusInstance.use(new LoggingMiddleware());
    
    // Add metrics middleware if available
    if (process.env.ENABLE_EVENT_METRICS === 'true') {
      // Would integrate with actual metrics service
      console.log('Event metrics middleware would be enabled here');
    }
  }
  
  return eventBusInstance;
}

/**
 * Reset event bus (for testing)
 */
export function resetEventBus(): void {
  eventBusInstance = null;
}
