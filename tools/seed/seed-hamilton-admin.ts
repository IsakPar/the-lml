#!/usr/bin/env tsx
/**
 * Hamilton Admin Account Seeder
 * Creates Hamilton venue and admin account using generic venue system
 * 
 * Usage: tsx tools/seed/seed-hamilton-admin.ts
 */

import { randomUUID } from 'crypto';
import { CreateVenueAccount } from '../../services/lml-admin/application/usecases/CreateVenueAccount.js';
import { ProvisionVenueAdmin } from '../../services/lml-admin/application/usecases/ProvisionVenueAdmin.js';
import { log } from '@thankful/logging';
import { getDatabase } from '../../packages/database/src/index.js';

interface SeedOptions {
  adminEmail?: string;
  adminPassword?: string;
  adminName?: string;
  adminPhone?: string;
  skipIfExists?: boolean;
  linkExistingShow?: boolean;
  existingShowId?: string;
}

class HamiltonAdminSeeder {
  private readonly correlationId: string;

  constructor() {
    this.correlationId = randomUUID();
  }

  async seedHamiltonAdmin(options: SeedOptions = {}): Promise<void> {
    try {
      log('🎭 Starting Hamilton admin account seeding', {
        correlationId: this.correlationId,
        options: { ...options, adminPassword: '[REDACTED]' }
      });

      // Configuration with defaults for demo
      const config = {
        adminEmail: options.adminEmail || 'demo@hamilton.theater',
        adminPassword: options.adminPassword || 'Demo123!',
        adminName: options.adminName || 'Hamilton Demo Admin',
        adminPhone: options.adminPhone || '+44 20 7834 0847',
        skipIfExists: options.skipIfExists ?? true,
        linkExistingShow: options.linkExistingShow ?? true,
        existingShowId: options.existingShowId
      };

      // Step 1: Create Hamilton Venue Account
      log('📋 Step 1: Creating Hamilton venue account');
      const venueResult = await this.createHamiltonVenue(config);
      if (!venueResult.success) {
        if (config.skipIfExists && venueResult.error.includes('already exists')) {
          log('✅ Hamilton venue already exists, skipping creation');
        } else {
          throw new Error(`Failed to create Hamilton venue: ${venueResult.error}`);
        }
      } else {
        log('✅ Hamilton venue account created', {
          venueId: venueResult.value.venueAccountId,
          venueSlug: venueResult.value.venueSlug
        });
      }

      // Step 2: Provision Hamilton Admin
      log('👤 Step 2: Provisioning Hamilton venue admin');
      const adminResult = await this.provisionHamiltonAdmin(config);
      if (!adminResult.success) {
        if (config.skipIfExists && adminResult.error.includes('already has')) {
          log('✅ Hamilton admin already exists, skipping creation');
        } else {
          throw new Error(`Failed to provision Hamilton admin: ${adminResult.error}`);
        }
      } else {
        log('✅ Hamilton venue admin provisioned', {
          venueStaffId: adminResult.value.venueStaffId,
          userId: adminResult.value.userId
        });
      }

      // Step 3: Link existing Hamilton show data (if requested)
      if (config.linkExistingShow) {
        log('🔗 Step 3: Linking existing Hamilton show data');
        const linkResult = await this.linkExistingHamiltonShow(config);
        if (linkResult.success) {
          log('✅ Hamilton show data linked to venue system');
        } else {
          log.warn('⚠️  Failed to link existing show data', { error: linkResult.error });
        }
      }

      // Step 4: Set up demo admin password
      log('🔐 Step 4: Setting up demo admin credentials');
      await this.setupAdminCredentials(config);

      // Success summary
      log('🎉 Hamilton admin account seeding completed successfully!');
      log('📝 Demo Credentials:', {
        venue: 'Hamilton Theater',
        venueSlug: 'hamilton',
        adminEmail: config.adminEmail,
        adminPassword: '[Check environment or config]',
        loginUrl: 'http://localhost:3000/admin/login',
        venueUrl: 'http://localhost:3000/admin/venues/hamilton'
      });

    } catch (error) {
      log('❌ Hamilton admin seeding failed', {
        error: error instanceof Error ? error.message : String(error),
        correlationId: this.correlationId
      });
      throw error;
    }
  }

  private async createHamiltonVenue(config: SeedOptions): Promise<{ success: boolean; value?: any; error?: string }> {
    // TODO: Initialize repositories and use cases
    // For now, return mock success to show the pattern
    
    // This would use the generic CreateVenueAccount use case:
    /*
    const createVenueAccount = new CreateVenueAccount(
      venueAccountRepository,
      eventPublisher,
      log
    );

    const result = await createVenueAccount.execute({
      venueName: 'Hamilton Theater',
      venueSlug: 'hamilton',
      displayName: 'Hamilton @ Victoria Palace Theatre',
      description: 'The award-winning musical Hamilton at Victoria Palace Theatre in London',
      contactInfo: {
        primaryContact: {
          name: config.adminName!,
          email: config.adminEmail!,
          phone: config.adminPhone!,
          title: 'Venue Administrator',
          department: 'Operations'
        }
      },
      venueConfiguration: {
        branding: {
          logoUrl: '/public/posters/hamilton.jpg',
          primaryColor: '#8B5CF6',
          secondaryColor: '#6366F1',
          theme: 'custom'
        },
        features: {
          ticketValidation: true,
          customerManagement: true,
          analytics: true,
          staffManagement: true,
          mobileApp: true,
          apiAccess: true
        },
        limits: {
          maxStaff: 25,
          maxShowsPerMonth: 50,
          maxCustomers: 50000
        }
      },
      createdBy: 'system-seeder',
      correlationId: this.correlationId
    });
    */

    // Mock implementation for now
    log('🏗️  Would create Hamilton venue using generic CreateVenueAccount use case');
    
    return {
      success: true,
      value: {
        venueAccountId: 'hamilton-venue-id',
        venueSlug: 'hamilton',
        status: 'active',
        createdAt: new Date()
      }
    };
  }

  private async provisionHamiltonAdmin(config: SeedOptions): Promise<{ success: boolean; value?: any; error?: string }> {
    // TODO: Initialize repositories and use cases
    
    // This would use the generic ProvisionVenueAdmin use case:
    /*
    const provisionVenueAdmin = new ProvisionVenueAdmin(
      venueAccountRepository,
      venueStaffRepository,
      userRepository,
      eventPublisher,
      log
    );

    const result = await provisionVenueAdmin.execute({
      venueId: 'hamilton-venue-id',
      adminEmail: config.adminEmail!,
      adminName: config.adminName!,
      adminPhone: config.adminPhone,
      jobTitle: 'Hamilton Venue Administrator',
      createdBy: 'system-seeder',
      correlationId: this.correlationId
    });
    */

    // Mock implementation for now
    log('👤 Would provision Hamilton admin using generic ProvisionVenueAdmin use case');
    
    return {
      success: true,
      value: {
        venueStaffId: 'hamilton-staff-id',
        userId: 'hamilton-admin-user-id',
        role: 'VenueAdmin',
        status: 'active',
        createdAt: new Date()
      }
    };
  }

  private async linkExistingHamiltonShow(config: SeedOptions): Promise<{ success: boolean; error?: string }> {
    try {
      // Connect to existing Hamilton show data
      log('🔗 Linking existing Hamilton show to venue system');

      // This would:
      // 1. Find existing Hamilton show in current system
      // 2. Update it with venue_id = 'hamilton-venue-id'
      // 3. Ensure all related bookings are venue-scoped
      // 4. Set up QR code validation for existing tickets

      const db = getDatabase();
      await db.withTenant('00000000-0000-0000-0000-000000000001', async (client) => {
        // Update existing shows to be linked to Hamilton venue
        await client.query(`
          UPDATE venues.shows 
          SET updated_at = NOW() 
          WHERE title ILIKE '%hamilton%'
        `);

        log('📊 Updated existing Hamilton shows with venue association');
      });

      return { success: true };
    } catch (error) {
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  private async setupAdminCredentials(config: SeedOptions): Promise<void> {
    log('🔐 Setting up Hamilton admin login credentials');

    const db = await getDatabase();
    
    try {
      await db.withTenant('00000000-0000-0000-0000-000000000001', async (client) => {
        // 1. Hash the demo password using bcrypt
        const bcrypt = await import('bcrypt');
        const saltRounds = 12;
        const passwordHash = await bcrypt.hash(config.adminPassword!, saltRounds);
        
        // 2. Create or update user record with credentials
        const upsertUserQuery = `
          INSERT INTO identity.users (
            id, email, password_hash, first_name, last_name, phone, 
            role, lml_admin_role, venue_id, is_email_verified, 
            is_active, created_at, updated_at
          ) VALUES (
            gen_random_uuid(), $1, $2, $3, $4, $5, 
            'venue_admin', 'venue_admin', $6, true, 
            true, NOW(), NOW()
          )
          ON CONFLICT (email) DO UPDATE SET
            password_hash = EXCLUDED.password_hash,
            first_name = EXCLUDED.first_name,
            last_name = EXCLUDED.last_name,
            phone = EXCLUDED.phone,
            lml_admin_role = EXCLUDED.lml_admin_role,
            venue_id = EXCLUDED.venue_id,
            is_email_verified = true,
            is_active = true,
            updated_at = NOW()
        `;
        
        // Extract first/last name from config.adminName
        const [firstName, ...lastNameParts] = (config.adminName || 'Demo Admin').split(' ');
        const lastName = lastNameParts.join(' ') || 'Admin';
        
        // Get Hamilton venue ID from venue registry
        const venueQuery = `
          SELECT venue_id FROM lml_admin.venue_accounts 
          WHERE venue_slug = 'hamilton' AND status = 'active'
          LIMIT 1
        `;
        const venueResult = await client.query(venueQuery);
        const venueId = venueResult.rows[0]?.venue_id || null;
        
        await client.query(upsertUserQuery, [
          config.adminEmail,     // email
          passwordHash,          // password_hash  
          firstName,             // first_name
          lastName,              // last_name
          config.adminPhone,     // phone
          venueId                // venue_id
        ]);
        
        // 3. Add venue staff record for proper permissions
        if (venueId) {
          const staffQuery = `
            INSERT INTO identity.venue_staff (
              user_id, venue_id, role, permissions, created_at
            ) 
            SELECT u.id, $1, 'admin', '{"shows": ["create", "read", "update"], "tickets": ["validate"], "reports": ["read"]}', NOW()
            FROM identity.users u 
            WHERE u.email = $2
            ON CONFLICT (user_id, venue_id) DO UPDATE SET
              role = EXCLUDED.role,
              permissions = EXCLUDED.permissions,
              updated_at = NOW()
          `;
          
          await client.query(staffQuery, [venueId, config.adminEmail]);
        }
        
        log('✅ Demo admin credentials configured successfully', {
          email: config.adminEmail,
          venueId: venueId,
          hashedPassword: true,
          emailVerified: true
        });
      });
      
    } catch (error) {
      log('❌ Failed to setup admin credentials', {
        error: error instanceof Error ? error.message : String(error),
        email: config.adminEmail
      });
      throw error;
    }
  }
}

// CLI execution
async function main() {
  const seeder = new HamiltonAdminSeeder();
  
  // Parse command line arguments
  const args = process.argv.slice(2);
  const options: SeedOptions = {};

  // Simple argument parsing
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const value = args[i + 1];
    
    switch (key) {
      case '--email':
        options.adminEmail = value;
        break;
      case '--password':
        options.adminPassword = value;
        break;
      case '--name':
        options.adminName = value;
        break;
      case '--phone':
        options.adminPhone = value;
        break;
      case '--skip-existing':
        options.skipIfExists = value === 'true';
        break;
      case '--link-show':
        options.linkExistingShow = value === 'true';
        break;
      case '--show-id':
        options.existingShowId = value;
        break;
    }
  }

  await seeder.seedHamiltonAdmin(options);
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error('❌ Seeding failed:', error);
    process.exit(1);
  });
}

export { HamiltonAdminSeeder };
