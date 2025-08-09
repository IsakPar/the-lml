import fs from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import { PostgresAdapter } from '../adapters/PostgresAdapter.js';

/**
 * Database Migration Runner
 * Handles schema migrations with versioning and rollback support
 */
export class MigrationRunner {
  constructor(private db: PostgresAdapter) {}

  /**
   * Run all pending migrations
   */
  async runMigrations(migrationsDir?: string): Promise<void> {
    const migrationsPath = migrationsDir || path.join(process.cwd(), 'packages/database/src/migrations');
    
    console.log('🔄 Starting database migrations...');
    
    // Ensure migration tracking table exists
    await this.ensureMigrationTable();
    
    // Get all migration files
    const migrationFiles = await this.getMigrationFiles(migrationsPath);
    
    // Get applied migrations
    const appliedMigrations = await this.getAppliedMigrations();
    
    // Filter pending migrations
    const pendingMigrations = migrationFiles.filter(
      file => !appliedMigrations.has(this.getVersionFromFilename(file))
    );
    
    if (pendingMigrations.length === 0) {
      console.log('✅ No pending migrations');
      return;
    }
    
    console.log(`📦 Found ${pendingMigrations.length} pending migrations`);
    
    // Run each migration in transaction
    for (const migrationFile of pendingMigrations) {
      await this.runSingleMigration(migrationsPath, migrationFile);
    }
    
    console.log('🎉 All migrations completed successfully');
  }

  /**
   * Rollback last migration
   */
  async rollbackLastMigration(): Promise<void> {
    const lastMigration = await this.getLastAppliedMigration();
    
    if (!lastMigration) {
      console.log('❌ No migrations to rollback');
      return;
    }
    
    console.log(`⏪ Rolling back migration: ${lastMigration.version}`);
    
    // Check if rollback file exists
    const rollbackFile = `rollback_${lastMigration.version}.sql`;
    const rollbackPath = path.join(process.cwd(), 'packages/database/src/migrations', rollbackFile);
    
    try {
      const rollbackSql = await fs.readFile(rollbackPath, 'utf-8');
      
      await this.db.transaction(async (client) => {
        // Execute rollback SQL
        await client.query(rollbackSql);
        
        // Remove from migration history
        await client.query(
          'DELETE FROM public.schema_migrations WHERE version = $1',
          [lastMigration.version]
        );
      });
      
      console.log(`✅ Successfully rolled back migration: ${lastMigration.version}`);
    } catch (error) {
      if ((error as any).code === 'ENOENT') {
        console.error(`❌ Rollback file not found: ${rollbackFile}`);
        console.error('Manual rollback required');
      } else {
        console.error(`❌ Rollback failed:`, error);
      }
      throw error;
    }
  }

  /**
   * Get migration status
   */
  async getMigrationStatus(): Promise<{
    applied: Array<{ version: string; applied_at: string }>;
    pending: string[];
  }> {
    const migrationsPath = path.join(process.cwd(), 'packages/database/src/migrations');
    
    // Get all migration files
    const migrationFiles = await this.getMigrationFiles(migrationsPath);
    
    // Get applied migrations
    const appliedMigrations = await this.db.queryMany<{ version: string; applied_at: string }>(
      'SELECT version, applied_at FROM public.schema_migrations ORDER BY applied_at'
    );
    
    // Get pending migrations
    const appliedVersions = new Set(appliedMigrations.map(m => m.version));
    const pendingMigrations = migrationFiles
      .filter(file => !appliedVersions.has(this.getVersionFromFilename(file)))
      .map(file => this.getVersionFromFilename(file));
    
    return {
      applied: appliedMigrations,
      pending: pendingMigrations,
    };
  }

  /**
   * Create a new migration file
   */
  async createMigration(name: string, content: string = ''): Promise<string> {
    const migrationsPath = path.join(process.cwd(), 'packages/database/src/migrations');
    
    // Get next version number
    const existingMigrations = await this.getMigrationFiles(migrationsPath);
    const lastVersion = existingMigrations.length > 0 
      ? Math.max(...existingMigrations.map(f => parseInt(this.getVersionFromFilename(f))))
      : 0;
    
    const nextVersion = String(lastVersion + 1).padStart(3, '0');
    const filename = `${nextVersion}_${name.toLowerCase().replace(/\s+/g, '_')}.sql`;
    const filepath = path.join(migrationsPath, filename);
    
    const migrationTemplate = content || `-- Migration ${nextVersion}: ${name}
-- Description: Add your migration description here

-- Start transaction
BEGIN;

-- Add your migration SQL here


-- Record migration
INSERT INTO public.schema_migrations (version, checksum) 
VALUES ('${nextVersion}', 'PLACEHOLDER_CHECKSUM');

COMMIT;
`;
    
    await fs.writeFile(filepath, migrationTemplate);
    console.log(`📝 Created migration: ${filename}`);
    
    return filepath;
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  private async ensureMigrationTable(): Promise<void> {
    await this.db.query(`
      CREATE TABLE IF NOT EXISTS public.schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        checksum VARCHAR(64) NOT NULL
      )
    `);
  }

  private async getMigrationFiles(migrationsPath: string): Promise<string[]> {
    try {
      const files = await fs.readdir(migrationsPath);
      return files
        .filter(file => file.endsWith('.sql') && !file.startsWith('rollback_'))
        .sort((a, b) => {
          const versionA = parseInt(this.getVersionFromFilename(a));
          const versionB = parseInt(this.getVersionFromFilename(b));
          return versionA - versionB;
        });
    } catch (error) {
      if ((error as any).code === 'ENOENT') {
        console.warn(`⚠️  Migrations directory not found: ${migrationsPath}`);
        return [];
      }
      throw error;
    }
  }

  private getVersionFromFilename(filename: string): string {
    const match = filename.match(/^(\d+)_/);
    return match ? match[1] : '000';
  }

  private async getAppliedMigrations(): Promise<Set<string>> {
    try {
      const result = await this.db.queryMany<{ version: string }>(
        'SELECT version FROM public.schema_migrations'
      );
      return new Set(result.map(row => row.version));
    } catch (error) {
      // Table might not exist yet
      return new Set();
    }
  }

  private async getLastAppliedMigration(): Promise<{ version: string; applied_at: string } | null> {
    try {
      return await this.db.queryOne<{ version: string; applied_at: string }>(
        'SELECT version, applied_at FROM public.schema_migrations ORDER BY applied_at DESC LIMIT 1'
      );
    } catch (error) {
      return null;
    }
  }

  private async runSingleMigration(migrationsPath: string, migrationFile: string): Promise<void> {
    const version = this.getVersionFromFilename(migrationFile);
    const filepath = path.join(migrationsPath, migrationFile);
    
    console.log(`⚡ Running migration: ${migrationFile}`);
    
    // Read migration file
    const migrationSql = await fs.readFile(filepath, 'utf-8');
    
    // Calculate checksum
    const checksum = this.calculateChecksum(migrationSql);
    
    // Run migration in transaction
    await this.db.transaction(async (client) => {
      // Replace placeholder checksum if exists
      const sqlWithChecksum = migrationSql.replace('PLACEHOLDER_CHECKSUM', checksum);
      
      // Execute migration
      await client.query(sqlWithChecksum);
      
      // Record migration if not already recorded
      const existingRecord = await client.query(
        'SELECT 1 FROM public.schema_migrations WHERE version = $1',
        [version]
      );
      
      if (existingRecord.rows.length === 0) {
        await client.query(
          'INSERT INTO public.schema_migrations (version, checksum) VALUES ($1, $2)',
          [version, checksum]
        );
      }
    });
    
    console.log(`✅ Migration completed: ${migrationFile}`);
  }

  private calculateChecksum(content: string): string {
    return crypto.createHash('sha256').update(content).digest('hex');
  }
}

/**
 * CLI helper for migrations
 */
export async function runMigrationCLI(args: string[]): Promise<void> {
  const command = args[0];
  
  // Initialize database connection
  const { getDatabase } = await import('../adapters/PostgresAdapter.js');
  const db = getDatabase();
  const runner = new MigrationRunner(db);
  
  try {
    switch (command) {
      case 'up':
      case 'migrate':
        await runner.runMigrations();
        break;
        
      case 'down':
      case 'rollback':
        await runner.rollbackLastMigration();
        break;
        
      case 'status':
        const status = await runner.getMigrationStatus();
        console.log('\n📊 Migration Status:');
        console.log(`Applied: ${status.applied.length}`);
        console.log(`Pending: ${status.pending.length}`);
        
        if (status.applied.length > 0) {
          console.log('\n✅ Applied migrations:');
          status.applied.forEach(m => {
            console.log(`  ${m.version} - ${m.applied_at}`);
          });
        }
        
        if (status.pending.length > 0) {
          console.log('\n⏳ Pending migrations:');
          status.pending.forEach(version => {
            console.log(`  ${version}`);
          });
        }
        break;
        
      case 'create':
        const name = args[1];
        if (!name) {
          console.error('❌ Migration name required: npm run migration create "migration_name"');
          process.exit(1);
        }
        await runner.createMigration(name);
        break;
        
      default:
        console.log(`
📚 Database Migration Commands:

  npm run migration up       - Run all pending migrations
  npm run migration down     - Rollback last migration  
  npm run migration status   - Show migration status
  npm run migration create "name" - Create new migration

Examples:
  npm run migration up
  npm run migration create "add_user_preferences"
  npm run migration status
        `);
    }
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await db.close();
  }
}
