/**
 * Dependency Injection Container
 * Wires together all layers of the clean architecture
 */
export class DIContainer {
  private services = new Map<string, any>();
  private singletons = new Map<string, any>();
  private factories = new Map<string, () => any>();

  /**
   * Register a singleton service
   */
  registerSingleton<T>(key: string, factory: () => T): void {
    this.factories.set(key, factory);
  }

  /**
   * Register a transient service
   */
  registerTransient<T>(key: string, factory: () => T): void {
    this.services.set(key, factory);
  }

  /**
   * Register an instance
   */
  registerInstance<T>(key: string, instance: T): void {
    this.singletons.set(key, instance);
  }

  /**
   * Resolve a service
   */
  resolve<T>(key: string): T {
    // Check for existing singleton
    if (this.singletons.has(key)) {
      return this.singletons.get(key);
    }

    // Check for singleton factory
    if (this.factories.has(key)) {
      const instance = this.factories.get(key)!();
      this.singletons.set(key, instance);
      return instance;
    }

    // Check for transient factory
    if (this.services.has(key)) {
      return this.services.get(key)!();
    }

    throw new Error(`Service '${key}' not registered`);
  }

  /**
   * Check if service is registered
   */
  isRegistered(key: string): boolean {
    return this.singletons.has(key) || 
           this.factories.has(key) || 
           this.services.has(key);
  }

  /**
   * Clear all registrations (useful for testing)
   */
  clear(): void {
    this.services.clear();
    this.singletons.clear();
    this.factories.clear();
  }
}

/**
 * Service registration keys
 */
export const ServiceKeys = {
  // Database adapters
  POSTGRES_ADAPTER: 'PostgresAdapter',
  REDIS_ADAPTER: 'RedisAdapter',
  MONGO_CLIENT: 'MongoClient',

  // Identity services
  USER_REPOSITORY: 'UserRepository',
  SESSION_REPOSITORY: 'SessionRepository',
  PASSWORD_SERVICE: 'PasswordService',
  AUTHENTICATE_USER: 'AuthenticateUser',
  REGISTER_USER: 'RegisterUser',

  // Ticketing services
  EVENT_REPOSITORY: 'EventRepository',
  CREATE_EVENT: 'CreateEvent',

  // Inventory services
  SEAT_LOCK_SERVICE: 'SeatLockService',
  ACQUIRE_SEAT_LOCKS: 'AcquireSeatLocks',

  // Venues services
  SEATMAP_REPOSITORY: 'SeatmapRepository',

  // Event system
  EVENT_BUS: 'EventBus',

  // Platform services
  RATE_LIMIT_SERVICE: 'RateLimitService',
  EVENT_VALIDATION_SERVICE: 'EventValidationService',
} as const;

/**
 * Global container instance
 */
let containerInstance: DIContainer | null = null;

export function getContainer(): DIContainer {
  if (!containerInstance) {
    containerInstance = new DIContainer();
  }
  return containerInstance;
}

export function resetContainer(): void {
  containerInstance = null;
}
