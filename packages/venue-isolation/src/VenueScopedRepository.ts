import { Result } from '@thankful/result';
import { Logger } from '@thankful/logging';
import { VenueContext, VenueAccessError, VenueAccessErrorCode } from './types.js';

/**
 * Base repository class that automatically enforces venue isolation
 * All database queries are scoped to the venue context
 */
export abstract class VenueScopedRepository<TEntity, TId = string> {
  protected readonly logger: Logger;
  protected venueContext?: VenueContext;

  constructor(
    protected readonly tableName: string,
    logger?: Logger
  ) {
    this.logger = logger || new Logger({ 
      service: `venue-scoped-repository-${tableName}` 
    });
  }

  /**
   * Set the venue context for all subsequent operations
   */
  setVenueContext(context: VenueContext): void {
    this.venueContext = context;
    this.logger.debug('Venue context set for repository', {
      venueId: context.venueId,
      tableName: this.tableName,
      correlationId: context.correlationId
    });
  }

  /**
   * Clear the venue context
   */
  clearVenueContext(): void {
    this.venueContext = undefined;
    this.logger.debug('Venue context cleared for repository', {
      tableName: this.tableName
    });
  }

  /**
   * Execute a database operation within venue context
   */
  protected async executeInVenueContext<T>(
    operation: string,
    callback: (venueId: string) => Promise<T>
  ): Promise<Result<T, VenueAccessError>> {
    if (!this.venueContext) {
      this.logger.error('Attempted to execute venue operation without context', {
        operation,
        tableName: this.tableName
      });

      return Result.failure(new VenueAccessError(
        'No venue context available for database operation',
        VenueAccessErrorCode.NO_VENUE_ACCESS
      ));
    }

    try {
      this.logger.debug('Executing venue-scoped operation', {
        operation,
        venueId: this.venueContext.venueId,
        tableName: this.tableName,
        correlationId: this.venueContext.correlationId
      });

      // Set database session context for RLS
      await this.setDatabaseContext(this.venueContext);

      const result = await callback(this.venueContext.venueId);

      this.logger.debug('Venue-scoped operation completed successfully', {
        operation,
        venueId: this.venueContext.venueId,
        tableName: this.tableName,
        correlationId: this.venueContext.correlationId
      });

      return Result.success(result);
    } catch (error) {
      this.logger.error('Venue-scoped operation failed', {
        error: error.message,
        operation,
        venueId: this.venueContext.venueId,
        tableName: this.tableName,
        correlationId: this.venueContext.correlationId
      });

      return Result.failure(new VenueAccessError(
        `Database operation failed: ${error.message}`,
        VenueAccessErrorCode.BOUNDARY_VIOLATION,
        this.venueContext.venueId,
        this.venueContext.userId
      ));
    } finally {
      // Clean up database context
      await this.clearDatabaseContext();
    }
  }

  /**
   * Find entity by ID within venue scope
   */
  async findById(id: TId): Promise<Result<TEntity | null, VenueAccessError>> {
    return this.executeInVenueContext('findById', async (venueId) => {
      return this.doFindById(id, venueId);
    });
  }

  /**
   * Find entities by criteria within venue scope
   */
  async findByVenue(criteria: Record<string, any> = {}): Promise<Result<TEntity[], VenueAccessError>> {
    return this.executeInVenueContext('findByVenue', async (venueId) => {
      return this.doFindByVenue(criteria, venueId);
    });
  }

  /**
   * Save entity with venue scope
   */
  async save(entity: TEntity): Promise<Result<TEntity, VenueAccessError>> {
    return this.executeInVenueContext('save', async (venueId) => {
      return this.doSave(entity, venueId);
    });
  }

  /**
   * Update entity within venue scope
   */
  async update(id: TId, updates: Partial<TEntity>): Promise<Result<TEntity, VenueAccessError>> {
    return this.executeInVenueContext('update', async (venueId) => {
      return this.doUpdate(id, updates, venueId);
    });
  }

  /**
   * Delete entity within venue scope
   */
  async delete(id: TId): Promise<Result<void, VenueAccessError>> {
    return this.executeInVenueContext('delete', async (venueId) => {
      return this.doDelete(id, venueId);
    });
  }

  /**
   * Count entities within venue scope
   */
  async count(criteria: Record<string, any> = {}): Promise<Result<number, VenueAccessError>> {
    return this.executeInVenueContext('count', async (venueId) => {
      return this.doCount(criteria, venueId);
    });
  }

  /**
   * Check if entity exists within venue scope
   */
  async exists(id: TId): Promise<Result<boolean, VenueAccessError>> {
    return this.executeInVenueContext('exists', async (venueId) => {
      return this.doExists(id, venueId);
    });
  }

  /**
   * Execute custom query within venue scope
   */
  async executeQuery<T>(
    queryName: string,
    queryCallback: (venueId: string) => Promise<T>
  ): Promise<Result<T, VenueAccessError>> {
    return this.executeInVenueContext(queryName, queryCallback);
  }

  /**
   * Abstract methods that must be implemented by concrete repositories
   */
  protected abstract doFindById(id: TId, venueId: string): Promise<TEntity | null>;
  protected abstract doFindByVenue(criteria: Record<string, any>, venueId: string): Promise<TEntity[]>;
  protected abstract doSave(entity: TEntity, venueId: string): Promise<TEntity>;
  protected abstract doUpdate(id: TId, updates: Partial<TEntity>, venueId: string): Promise<TEntity>;
  protected abstract doDelete(id: TId, venueId: string): Promise<void>;
  protected abstract doCount(criteria: Record<string, any>, venueId: string): Promise<number>;
  protected abstract doExists(id: TId, venueId: string): Promise<boolean>;

  /**
   * Set database session context for Row Level Security
   */
  protected async setDatabaseContext(context: VenueContext): Promise<void> {
    // This would set the database session variables used by RLS policies
    // Implementation depends on your database client (pg, prisma, etc.)
    
    this.logger.debug('Setting database context for RLS', {
      venueId: context.venueId,
      userId: context.userId,
      correlationId: context.correlationId
    });

    // Example for PostgreSQL with node-postgres:
    // await this.db.query('SET app.venue_id = $1', [context.venueId]);
    // await this.db.query('SET app.user_id = $1', [context.userId || null]);
    // await this.db.query('SET app.correlation_id = $1', [context.correlationId || null]);
  }

  /**
   * Clear database session context
   */
  protected async clearDatabaseContext(): Promise<void> {
    this.logger.debug('Clearing database context');

    // Example for PostgreSQL:
    // await this.db.query('RESET app.venue_id');
    // await this.db.query('RESET app.user_id');
    // await this.db.query('RESET app.correlation_id');
  }

  /**
   * Ensure entity has venue_id field set correctly
   */
  protected ensureVenueId<T extends Record<string, any>>(entity: T, venueId: string): T {
    return {
      ...entity,
      venue_id: venueId,
      updated_at: new Date()
    };
  }

  /**
   * Validate that entity belongs to current venue
   */
  protected validateEntityVenue<T extends Record<string, any>>(entity: T, venueId: string): boolean {
    if (!entity.venue_id) {
      return false;
    }
    return entity.venue_id === venueId;
  }

  /**
   * Build venue-scoped WHERE clause
   */
  protected buildVenueWhereClause(criteria: Record<string, any>, venueId: string): Record<string, any> {
    return {
      ...criteria,
      venue_id: venueId
    };
  }

  /**
   * Log repository operation for audit trail
   */
  protected logRepositoryOperation(
    operation: string,
    entityId?: TId,
    success: boolean = true,
    error?: string
  ): void {
    this.logger.info('Repository operation', {
      operation,
      tableName: this.tableName,
      entityId,
      success,
      error,
      venueId: this.venueContext?.venueId,
      userId: this.venueContext?.userId,
      correlationId: this.venueContext?.correlationId,
      timestamp: new Date().toISOString()
    });
  }
}

