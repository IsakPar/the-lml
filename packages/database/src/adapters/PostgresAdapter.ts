import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';

/**
 * PostgreSQL Database Adapter
 * Provides connection pooling and query execution for all bounded contexts
 */
export class PostgresAdapter {
  private pool: Pool;
  private isConnected = false;

  constructor(connectionConfig: {
    host: string;
    port: number;
    database: string;
    user: string;
    password: string;
    ssl?: boolean;
    max?: number; // Max connections in pool
    idleTimeoutMillis?: number;
    connectionTimeoutMillis?: number;
  }) {
    this.pool = new Pool({
      host: connectionConfig.host,
      port: connectionConfig.port,
      database: connectionConfig.database,
      user: connectionConfig.user,
      password: connectionConfig.password,
      ssl: connectionConfig.ssl ? { rejectUnauthorized: false } : false,
      
      // Connection pool settings
      max: connectionConfig.max || 20, // Maximum number of connections
      idleTimeoutMillis: connectionConfig.idleTimeoutMillis || 30000, // 30 seconds
      connectionTimeoutMillis: connectionConfig.connectionTimeoutMillis || 2000, // 2 seconds
      
      // Enable keep-alive for long-running connections
      keepAlive: true,
      keepAliveInitialDelayMillis: 10000,
    });

    // Handle pool errors
    this.pool.on('error', (err) => {
      console.error('PostgreSQL pool error:', err);
    });

    this.pool.on('connect', () => {
      if (!this.isConnected) {
        console.log('PostgreSQL connected successfully');
        this.isConnected = true;
      }
    });
  }

  /**
   * Execute a query with parameters
   */
  async query<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<QueryResult<T>> {
    const start = Date.now();
    
    try {
      const result = await this.pool.query(text, params);
      const duration = Date.now() - start;
      
      // Log slow queries (> 100ms)
      if (duration > 100) {
        console.warn(`Slow query (${duration}ms):`, text.substring(0, 100));
      }
      
      return result;
    } catch (error) {
      console.error('PostgreSQL query error:', error);
      console.error('Query:', text);
      console.error('Params:', params);
      throw error;
    }
  }

  /**
   * Execute a query and return only the first row
   */
  async queryOne<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<T | null> {
    const result = await this.query<T>(text, params);
    return result.rows[0] || null;
  }

  /**
   * Execute a query and return all rows
   */
  async queryMany<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<T[]> {
    const result = await this.query<T>(text, params);
    return result.rows;
  }

  /**
   * Execute multiple queries in a transaction
   */
  async transaction<T>(
    callback: (client: PoolClient) => Promise<T>
  ): Promise<T> {
    const client = await this.pool.connect();
    
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Execute a batch of queries efficiently
   */
  async batch(queries: Array<{ text: string; params?: any[] }>): Promise<QueryResult[]> {
    return this.transaction(async (client) => {
      const results: QueryResult[] = [];
      
      for (const query of queries) {
        const result = await client.query(query.text, query.params);
        results.push(result);
      }
      
      return results;
    });
  }

  /**
   * Test database connectivity
   */
  async healthCheck(): Promise<boolean> {
    try {
      await this.query('SELECT 1');
      return true;
    } catch (error) {
      console.error('PostgreSQL health check failed:', error);
      return false;
    }
  }

  /**
   * Get connection pool status
   */
  getPoolStatus() {
    return {
      totalCount: this.pool.totalCount,
      idleCount: this.pool.idleCount,
      waitingCount: this.pool.waitingCount,
    };
  }

  /**
   * Close all connections
   */
  async close(): Promise<void> {
    await this.pool.end();
    this.isConnected = false;
    console.log('PostgreSQL connections closed');
  }
}

/**
 * Repository base class for all bounded contexts
 * Provides common database operations with proper error handling
 */
export abstract class BaseRepository {
  constructor(protected db: PostgresAdapter) {}

  /**
   * Generate a new UUID
   */
  protected async generateId(): Promise<string> {
    const result = await this.db.queryOne<{ uuid: string }>('SELECT uuid_generate_v4() as uuid');
    return result!.uuid;
  }

  /**
   * Check if a record exists by ID
   */
  protected async exists(tableName: string, id: string): Promise<boolean> {
    const result = await this.db.queryOne<{ exists: boolean }>(
      `SELECT EXISTS(SELECT 1 FROM ${tableName} WHERE id = $1) as exists`,
      [id]
    );
    return result!.exists;
  }

  /**
   * Soft delete a record (if table has deleted_at column)
   */
  protected async softDelete(tableName: string, id: string): Promise<void> {
    await this.db.query(
      `UPDATE ${tableName} SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
  }

  /**
   * Get paginated results
   */
  protected async paginate<T extends QueryResultRow>(
    baseQuery: string,
    params: any[],
    page: number = 1,
    limit: number = 20
  ): Promise<{ data: T[]; total: number; page: number; pages: number }> {
    // Get total count
    const countQuery = `SELECT COUNT(*) as total FROM (${baseQuery}) as count_query`;
    const totalResult = await this.db.queryOne<{ total: string }>(countQuery, params);
    const total = parseInt(totalResult!.total);

    // Get paginated data
    const offset = (page - 1) * limit;
    const dataQuery = `${baseQuery} LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    const data = await this.db.queryMany<T>(dataQuery, [...params, limit, offset]);

    return {
      data,
      total,
      page,
      pages: Math.ceil(total / limit),
    };
  }

  /**
   * Execute raw SQL with proper logging
   */
  protected async executeRaw<T extends QueryResultRow>(query: string, params?: any[]): Promise<T[]> {
    return this.db.queryMany<T>(query, params);
  }
}

/**
 * Database configuration factory
 */
export class DatabaseConfig {
  static fromEnvironment(): {
    host: string;
    port: number;
    database: string;
    user: string;
    password: string;
    ssl?: boolean;
    max?: number;
  } {
    const databaseUrl = process.env.DATABASE_URL;
    
    if (databaseUrl) {
      // Parse connection string
      const url = new URL(databaseUrl);
      return {
        host: url.hostname,
        port: parseInt(url.port) || 5432,
        database: url.pathname.substring(1),
        user: url.username,
        password: url.password,
        ssl: process.env.NODE_ENV === 'production',
        max: parseInt(process.env.DB_POOL_MAX || '20'),
      };
    }

    // Fallback to individual environment variables
    return {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'thankful',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      ssl: process.env.DB_SSL === 'true',
      max: parseInt(process.env.DB_POOL_MAX || '20'),
    };
  }
}

/**
 * Singleton database instance
 */
let dbInstance: PostgresAdapter | null = null;

export function getDatabase(): PostgresAdapter {
  if (!dbInstance) {
    const config = DatabaseConfig.fromEnvironment();
    dbInstance = new PostgresAdapter(config);
  }
  return dbInstance;
}

export async function closeDatabaseConnection(): Promise<void> {
  if (dbInstance) {
    await dbInstance.close();
    dbInstance = null;
  }
}
