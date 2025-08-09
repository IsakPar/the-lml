import { MongoClient } from 'mongodb';
import { getDatabase, getRedis } from '@thankful/database';
import { getEventBus } from '@thankful/events';
import { DIContainer, ServiceKeys } from './DIContainer.js';

// Infrastructure
import { PostgresUserRepository } from '../../../services/identity/infrastructure/repositories/PostgresUserRepository.js';
import { RedisSeatLockService } from '../../../services/inventory/infrastructure/services/RedisSeatLockService.js';
import { MongoSeatmapRepository } from '../../../services/venues/infrastructure/repositories/MongoSeatmapRepository.js';

// Use cases
import { AuthenticateUser } from '../../../services/identity/application/usecases/AuthenticateUser.js';
import { RegisterUser } from '../../../services/identity/application/usecases/RegisterUser.js';
import { CreateEvent } from '../../../services/ticketing/application/usecases/CreateEvent.js';
import { AcquireSeatLocks } from '../../../services/inventory/application/usecases/AcquireSeatLocks.js';

/**
 * Service Registry - configures the dependency injection container
 * This is where clean architecture layers are wired together
 */
export class ServiceRegistry {
  static async registerServices(container: DIContainer): Promise<void> {
    console.log('🔧 Registering services...');

    // ========================================================================
    // DATABASE ADAPTERS (Infrastructure Layer)
    // ========================================================================

    container.registerSingleton(ServiceKeys.POSTGRES_ADAPTER, () => {
      console.log('🐘 Initializing PostgreSQL adapter...');
      return getDatabase();
    });

    container.registerSingleton(ServiceKeys.REDIS_ADAPTER, () => {
      console.log('🔴 Initializing Redis adapter...');
      const redis = getRedis();
      // Ensure connection
      redis.connect().catch(console.error);
      return redis;
    });

    container.registerSingleton(ServiceKeys.MONGO_CLIENT, () => {
      console.log('🍃 Initializing MongoDB client...');
      const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/thankful';
      return new MongoClient(mongoUrl);
    });

    // ========================================================================
    // REPOSITORIES (Infrastructure Layer)
    // ========================================================================

    container.registerSingleton(ServiceKeys.USER_REPOSITORY, () => {
      const postgres = container.resolve(ServiceKeys.POSTGRES_ADAPTER) as any;
      return new PostgresUserRepository(postgres);
    });

    container.registerSingleton(ServiceKeys.SEAT_LOCK_SERVICE, () => {
      const redis = container.resolve(ServiceKeys.REDIS_ADAPTER) as any;
      return new RedisSeatLockService(redis);
    });

    container.registerSingleton(ServiceKeys.SEATMAP_REPOSITORY, () => {
      const mongo = container.resolve(ServiceKeys.MONGO_CLIENT) as MongoClient;
      return new MongoSeatmapRepository(mongo);
    });

    // ========================================================================
    // DOMAIN SERVICES (Application Layer)
    // ========================================================================

    container.registerSingleton(ServiceKeys.PASSWORD_SERVICE, () => {
      return new BcryptPasswordService();
    });

    container.registerSingleton(ServiceKeys.RATE_LIMIT_SERVICE, () => {
      const redis = container.resolve(ServiceKeys.REDIS_ADAPTER);
      return new RedisRateLimitService(redis);
    });

    container.registerSingleton(ServiceKeys.EVENT_VALIDATION_SERVICE, () => {
      return new EventValidationService();
    });

    // ========================================================================
    // USE CASES (Application Layer)
    // ========================================================================

    container.registerTransient(ServiceKeys.AUTHENTICATE_USER, () => {
      const userRepository = container.resolve(ServiceKeys.USER_REPOSITORY) as any;
      const sessionRepository = container.resolve(ServiceKeys.SESSION_REPOSITORY) as any;
      const passwordService = container.resolve(ServiceKeys.PASSWORD_SERVICE) as any;
      
      return new AuthenticateUser(userRepository, sessionRepository, passwordService);
    });

    container.registerTransient(ServiceKeys.REGISTER_USER, () => {
      const userRepository = container.resolve(ServiceKeys.USER_REPOSITORY) as any;
      const passwordService = container.resolve(ServiceKeys.PASSWORD_SERVICE) as any;
      
      return new RegisterUser(userRepository, passwordService);
    });

    container.registerTransient(ServiceKeys.CREATE_EVENT, () => {
      const eventRepository = container.resolve(ServiceKeys.EVENT_REPOSITORY) as any;
      return new CreateEvent(eventRepository);
    });

    container.registerTransient(ServiceKeys.ACQUIRE_SEAT_LOCKS, () => {
      const seatLockService = container.resolve(ServiceKeys.SEAT_LOCK_SERVICE) as any;
      const rateLimitService = container.resolve(ServiceKeys.RATE_LIMIT_SERVICE) as any;
      const eventValidationService = container.resolve(ServiceKeys.EVENT_VALIDATION_SERVICE) as any;
      
      return new AcquireSeatLocks(seatLockService, rateLimitService, eventValidationService);
    });

    // ========================================================================
    // EVENT SYSTEM (Cross-cutting)
    // ========================================================================

    container.registerSingleton(ServiceKeys.EVENT_BUS, () => {
      return getEventBus();
    });

    // ========================================================================
    // HEALTH CHECKS
    // ========================================================================

    // Verify all database connections
    await ServiceRegistry.performHealthChecks(container);

    console.log('✅ Service registration completed');
  }

  /**
   * Perform health checks on critical services
   */
  private static async performHealthChecks(container: DIContainer): Promise<void> {
    console.log('🔍 Performing health checks...');

    try {
      // Test PostgreSQL connection
      const postgres = container.resolve(ServiceKeys.POSTGRES_ADAPTER) as any;
      const pgHealth = await postgres.query('SELECT 1');
      if (!pgHealth) {
        throw new Error('PostgreSQL health check failed');
      }
      console.log('✅ PostgreSQL connection healthy');

      // Test Redis connection
      const redis = container.resolve(ServiceKeys.REDIS_ADAPTER) as any;
      const redisHealth = await redis.ping();
      if (redisHealth !== 'PONG') {
        throw new Error('Redis health check failed');
      }
      console.log('✅ Redis connection healthy');

      // Test MongoDB connection
      const mongo = container.resolve(ServiceKeys.MONGO_CLIENT) as MongoClient;
      await mongo.connect();
      await mongo.db('thankful').admin().ping();
      console.log('✅ MongoDB connection healthy');

    } catch (error) {
      console.error('❌ Health check failed:', error);
      throw new Error(`Service health check failed: ${error}`);
    }
  }
}

// ============================================================================
// SIMPLIFIED SERVICE IMPLEMENTATIONS
// ============================================================================

/**
 * Bcrypt password service implementation
 */
class BcryptPasswordService {
  async hash(password: string): Promise<any> {
    // Simplified - would use bcrypt in production
    return { isSuccess: true, value: `hashed_${password}` };
  }

  async verify(password: string, hash: string): Promise<any> {
    // Simplified verification
    return { isSuccess: true, value: hash === `hashed_${password}` };
  }

  validateStrength(password: string): any {
    // Simplified validation
    const isValid = password.length >= 8;
    return {
      isSuccess: true,
      value: {
        isValid,
        score: isValid ? 4 : 1,
        feedback: isValid ? [] : ['Password too short']
      }
    };
  }

  generateSecure(length = 12): string {
    return Math.random().toString(36).substring(2, length + 2);
  }

  needsRehash(hash: string): boolean {
    return false;
  }
}

/**
 * Redis rate limiting service
 */
class RedisRateLimitService {
  constructor(private redis: any) {}

  async checkLimit(userId: string, operation: string): Promise<any> {
    // Simplified rate limiting
    const key = `rate_limit:${operation}:${userId}:${Math.floor(Date.now() / 60000)}`;
    const count = await this.redis.incr(key);
    await this.redis.expire(key, 60);

    const limit = operation === 'seat_lock' ? 10 : 20;
    const allowed = count <= limit;

    return {
      isSuccess: true,
      value: {
        allowed,
        retryAfterSeconds: allowed ? undefined : 60
      }
    };
  }

  async recordAttempt(userId: string, operation: string): Promise<void> {
    // Implementation would record metrics
  }
}

/**
 * Event validation service
 */
class EventValidationService {
  async validateEventForBooking(eventId: string): Promise<any> {
    // Simplified validation
    return {
      isSuccess: true,
      value: {
        isOnSale: true,
        maxTicketsPerUser: 8
      }
    };
  }
}
