import { createClient, RedisClientType, RedisClusterType } from 'redis';

/**
 * Redis Adapter for seat locking, caching, and session management
 * Supports both standalone Redis and Redis Cluster
 */
export class RedisAdapter {
  private client: RedisClientType;
  private isConnected = false;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;

  constructor(
    private config: {
      url?: string;
      host?: string;
      port?: number;
      password?: string;
      database?: number;
      keyPrefix?: string;
      retryDelayMs?: number;
      commandTimeout?: number;
    }
  ) {
    const clientConfig = {
      url: config.url,
      socket: config.url ? undefined : {
        host: config.host || 'localhost',
        port: config.port || 6379,
        reconnectStrategy: (retries: number) => {
          if (retries >= this.maxReconnectAttempts) {
            console.error(`Redis reconnection failed after ${retries} attempts`);
            return new Error('Redis connection failed');
          }
          
          const delay = Math.min(retries * (config.retryDelayMs || 100), 3000);
          console.log(`Redis reconnecting in ${delay}ms (attempt ${retries})`);
          return delay;
        },
      },
      password: config.password,
      database: config.database || 0,
      commandsQueueMaxLength: 1000,
      lazyConnect: true,
    };

    this.client = createClient(clientConfig);

    // Event handlers
    this.client.on('connect', () => {
      console.log('Redis connecting...');
    });

    this.client.on('ready', () => {
      console.log('Redis connected and ready');
      this.isConnected = true;
      this.reconnectAttempts = 0;
    });

    this.client.on('error', (error) => {
      console.error('Redis error:', error);
      this.isConnected = false;
    });

    this.client.on('reconnecting', () => {
      console.log('Redis reconnecting...');
      this.reconnectAttempts++;
    });

    this.client.on('end', () => {
      console.log('Redis connection ended');
      this.isConnected = false;
    });
  }

  /**
   * Connect to Redis
   */
  async connect(): Promise<void> {
    if (!this.isConnected) {
      await this.client.connect();
    }
  }

  /**
   * Disconnect from Redis
   */
  async disconnect(): Promise<void> {
    if (this.isConnected) {
      await this.client.disconnect();
      this.isConnected = false;
    }
  }

  /**
   * Build key with optional prefix
   */
  private buildKey(key: string): string {
    return this.config.keyPrefix ? `${this.config.keyPrefix}:${key}` : key;
  }

  // ============================================================================
  // BASIC OPERATIONS
  // ============================================================================

  /**
   * Get a string value
   */
  async get(key: string): Promise<string | null> {
    return this.client.get(this.buildKey(key));
  }

  /**
   * Set a string value with optional TTL
   */
  async set(key: string, value: string, ttlSeconds?: number): Promise<string | null> {
    const fullKey = this.buildKey(key);
    if (ttlSeconds) {
      return this.client.setEx(fullKey, ttlSeconds, value);
    }
    return this.client.set(fullKey, value);
  }

  /**
   * Set if not exists (atomic)
   */
  async setNX(key: string, value: string, ttlSeconds?: number): Promise<boolean> {
    const fullKey = this.buildKey(key);
    if (ttlSeconds) {
      const result = await this.client.set(fullKey, value, { NX: true, EX: ttlSeconds });
      return result === 'OK';
    }
    const result = await this.client.setNX(fullKey, value);
    return Boolean(result);
  }

  /**
   * Set if exists (atomic)
   */
  async setXX(key: string, value: string, ttlSeconds?: number): Promise<boolean> {
    const fullKey = this.buildKey(key);
    if (ttlSeconds) {
      const result = await this.client.set(fullKey, value, { XX: true, EX: ttlSeconds });
      return result === 'OK';
    }
    const result = await this.client.set(fullKey, value, { XX: true });
    return result === 'OK';
  }

  /**
   * Delete keys
   */
  async del(...keys: string[]): Promise<number> {
    const fullKeys = keys.map(key => this.buildKey(key));
    return this.client.del(fullKeys);
  }

  /**
   * Check if key exists
   */
  async exists(key: string): Promise<boolean> {
    const result = await this.client.exists(this.buildKey(key));
    return Boolean(result);
  }

  /**
   * Set TTL on existing key
   */
  async expire(key: string, ttlSeconds: number): Promise<boolean> {
    const result = await this.client.expire(this.buildKey(key), ttlSeconds);
    return Boolean(result);
  }

  /**
   * Get TTL of a key
   */
  async ttl(key: string): Promise<number> {
    return this.client.ttl(this.buildKey(key));
  }

  // ============================================================================
  // HASH OPERATIONS
  // ============================================================================

  /**
   * Set hash field
   */
  async hSet(key: string, field: string, value: string): Promise<number> {
    return this.client.hSet(this.buildKey(key), field, value);
  }

  /**
   * Get hash field
   */
  async hGet(key: string, field: string): Promise<string | undefined> {
    const result = await this.client.hGet(this.buildKey(key), field);
    return result || undefined;
  }

  /**
   * Get all hash fields
   */
  async hGetAll(key: string): Promise<Record<string, string>> {
    return this.client.hGetAll(this.buildKey(key));
  }

  /**
   * Delete hash field
   */
  async hDel(key: string, field: string): Promise<number> {
    return this.client.hDel(this.buildKey(key), field);
  }

  // ============================================================================
  // SET OPERATIONS
  // ============================================================================

  /**
   * Add member to set
   */
  async sAdd(key: string, ...members: string[]): Promise<number> {
    return this.client.sAdd(this.buildKey(key), members);
  }

  /**
   * Remove member from set
   */
  async sRem(key: string, ...members: string[]): Promise<number> {
    return this.client.sRem(this.buildKey(key), members);
  }

  /**
   * Check if member exists in set
   */
  async sIsMember(key: string, member: string): Promise<boolean> {
    const result = await this.client.sIsMember(this.buildKey(key), member);
    return Boolean(result);
  }

  /**
   * Get all set members
   */
  async sMembers(key: string): Promise<string[]> {
    return this.client.sMembers(this.buildKey(key));
  }

  // ============================================================================
  // LIST OPERATIONS
  // ============================================================================

  /**
   * Push to left of list
   */
  async lPush(key: string, ...values: string[]): Promise<number> {
    return this.client.lPush(this.buildKey(key), values);
  }

  /**
   * Push to right of list
   */
  async rPush(key: string, ...values: string[]): Promise<number> {
    return this.client.rPush(this.buildKey(key), values);
  }

  /**
   * Pop from left of list
   */
  async lPop(key: string): Promise<string | null> {
    return this.client.lPop(this.buildKey(key));
  }

  /**
   * Pop from right of list
   */
  async rPop(key: string): Promise<string | null> {
    return this.client.rPop(this.buildKey(key));
  }

  /**
   * Get list length
   */
  async lLen(key: string): Promise<number> {
    return this.client.lLen(this.buildKey(key));
  }

  /**
   * Get list range
   */
  async lRange(key: string, start: number, stop: number): Promise<string[]> {
    return this.client.lRange(this.buildKey(key), start, stop);
  }

  // ============================================================================
  // LUA SCRIPT EXECUTION
  // ============================================================================

  /**
   * Execute Lua script
   */
  async eval(script: string, keys: string[], args: string[]): Promise<any> {
    const fullKeys = keys.map(key => this.buildKey(key));
    return this.client.eval(script, { keys: fullKeys, arguments: args });
  }

  /**
   * Execute Lua script by SHA
   */
  async evalSha(sha: string, keys: string[], args: string[]): Promise<any> {
    const fullKeys = keys.map(key => this.buildKey(key));
    return this.client.evalSha(sha, { keys: fullKeys, arguments: args });
  }

  /**
   * Load Lua script and return SHA
   */
  async scriptLoad(script: string): Promise<string> {
    return this.client.scriptLoad(script);
  }

  // ============================================================================
  // ATOMIC OPERATIONS
  // ============================================================================

  /**
   * Increment counter
   */
  async incr(key: string): Promise<number> {
    return this.client.incr(this.buildKey(key));
  }

  /**
   * Increment by amount
   */
  async incrBy(key: string, amount: number): Promise<number> {
    return this.client.incrBy(this.buildKey(key), amount);
  }

  /**
   * Decrement counter
   */
  async decr(key: string): Promise<number> {
    return this.client.decr(this.buildKey(key));
  }

  // ============================================================================
  // PATTERN OPERATIONS
  // ============================================================================

  /**
   * Get keys matching pattern
   */
  async keys(pattern: string): Promise<string[]> {
    const fullPattern = this.buildKey(pattern);
    const keys = await this.client.keys(fullPattern);
    
    // Remove prefix from returned keys
    if (this.config.keyPrefix) {
      const prefixLength = this.config.keyPrefix.length + 1;
      return keys.map(key => key.substring(prefixLength));
    }
    
    return keys;
  }

  /**
   * Scan keys with cursor (for large datasets)
   */
  async scan(cursor: number = 0, pattern?: string, count?: number): Promise<{
    cursor: number;
    keys: string[];
  }> {
    const options: any = {};
    if (pattern) options.MATCH = this.buildKey(pattern);
    if (count) options.COUNT = count;

    const result = await this.client.scan(cursor as any, options as any);
    
    // Remove prefix from returned keys
    let keys = (result.keys as any[]).map((k) => (typeof k === 'string' ? k : (k as Buffer).toString('utf8')));
    if (this.config.keyPrefix) {
      const prefixLength = this.config.keyPrefix.length + 1;
      keys = keys.map(key => (key as string).substring(prefixLength));
    }

    return {
      cursor: Number((result as any).cursor),
      keys: keys as string[],
    };
  }

  // ============================================================================
  // HEALTH & MONITORING
  // ============================================================================

  /**
   * Health check
   */
  async healthCheck(): Promise<boolean> {
    try {
      const result = await this.client.ping();
      return result === 'PONG';
    } catch (error) {
      console.error('Redis health check failed:', error);
      return false;
    }
  }

  /**
   * Get Redis info
   */
  async info(section?: string): Promise<string> {
    return this.client.info(section);
  }

  /**
   * Get memory usage for a key
   */
  async memoryUsage(key: string): Promise<number | null> {
    try {
      return await this.client.memoryUsage(this.buildKey(key));
    } catch (error) {
      // Command might not be available in older Redis versions
      return null;
    }
  }

  // ============================================================================
  // TRANSACTION SUPPORT
  // ============================================================================

  /**
   * Execute commands in a transaction
   */
  async multi(commands: Array<{ command: string; args: any[] }>): Promise<any[]> {
    const multi = this.client.multi();
    
    for (const cmd of commands) {
      // Apply key prefix to first argument if it looks like a key
      const args = [...cmd.args];
      if (args.length > 0 && typeof args[0] === 'string') {
        args[0] = this.buildKey(args[0]);
      }
      
      (multi as any)[cmd.command](...args);
    }
    
    return multi.exec();
  }

  /**
   * Get Redis client instance for advanced operations
   */
  getClient(): RedisClientType {
    return this.client;
  }

  /**
   * Check if connected
   */
  isReady(): boolean {
    return this.isConnected;
  }
}

/**
 * Redis configuration factory
 */
export class RedisConfig {
  static fromEnvironment(): {
    url?: string;
    host?: string;
    port?: number;
    password?: string;
    database?: number;
    keyPrefix?: string;
  } {
    const redisUrl = process.env.REDIS_URL;
    
    if (redisUrl) {
      return {
        url: redisUrl,
        keyPrefix: process.env.REDIS_KEY_PREFIX,
      };
    }

    return {
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379'),
      password: process.env.REDIS_PASSWORD,
      database: parseInt(process.env.REDIS_DB || '0'),
      keyPrefix: process.env.REDIS_KEY_PREFIX,
    };
  }
}

/**
 * Singleton Redis instance
 */
let redisInstance: RedisAdapter | null = null;

export function getRedis(): RedisAdapter {
  if (!redisInstance) {
    const config = RedisConfig.fromEnvironment();
    redisInstance = new RedisAdapter(config);
  }
  return redisInstance;
}

export async function closeRedisConnection(): Promise<void> {
  if (redisInstance) {
    await redisInstance.disconnect();
    redisInstance = null;
  }
}
