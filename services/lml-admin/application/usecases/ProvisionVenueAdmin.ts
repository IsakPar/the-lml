import { Result } from '@thankful/result';
import { Logger } from '@thankful/logging';
import { VenueAccountRepository } from '../ports/VenueAccountRepository.js';
import { VenueStaffRepository, VenueStaffRole, VenueStaffPermissions } from '../ports/VenueStaffRepository.js';
import { UserRepository } from '../ports/UserRepository.js';
import { DomainEventPublisher } from '@thankful/events';

/**
 * Generic use case to provision venue admin for any venue
 */
export interface ProvisionVenueAdminRequest {
  venueId: string;
  adminEmail: string;
  adminName: string;
  adminPhone?: string;
  jobTitle?: string;
  permissions?: Partial<VenueStaffPermissions>;
  createdBy: string;
  correlationId?: string;
}

export interface ProvisionVenueAdminResponse {
  venueStaffId: string;
  userId: string;
  venueId: string;
  role: string;
  status: string;
  createdAt: Date;
}

export class ProvisionVenueAdmin {
  private readonly logger: Logger;

  constructor(
    private readonly venueAccountRepository: VenueAccountRepository,
    private readonly venueStaffRepository: VenueStaffRepository,
    private readonly userRepository: UserRepository,
    private readonly eventPublisher: DomainEventPublisher,
    logger?: Logger
  ) {
    this.logger = logger || new Logger({ service: 'provision-venue-admin' });
  }

  async execute(
    request: ProvisionVenueAdminRequest
  ): Promise<Result<ProvisionVenueAdminResponse, string>> {
    try {
      this.logger.info('Provisioning venue admin', {
        venueId: request.venueId,
        adminEmail: request.adminEmail,
        createdBy: request.createdBy,
        correlationId: request.correlationId
      });

      // Validate request
      const validation = this.validateRequest(request);
      if (!validation.success) {
        return validation;
      }

      // Verify venue exists and is active
      const venueResult = await this.venueAccountRepository.findById(request.venueId);
      if (!venueResult.success || !venueResult.value) {
        return Result.failure('Venue not found');
      }

      const venue = venueResult.value;
      if (!venue.isOperational()) {
        return Result.failure('Cannot provision admin for inactive venue');
      }

      // Find or create user
      const userResult = await this.findOrCreateUser(request);
      if (!userResult.success) {
        return Result.failure(`Failed to find or create user: ${userResult.error}`);
      }
      const user = userResult.value;

      // Check if user already has staff role in this venue
      const existingStaff = await this.venueStaffRepository.findByUserAndVenue(user.id, request.venueId);
      if (existingStaff.success && existingStaff.value) {
        return Result.failure('User already has a staff role in this venue');
      }

      // Create venue admin permissions
      const adminPermissions = this.createVenueAdminPermissions(request.permissions);

      // Create venue staff record
      const staffResult = await this.venueStaffRepository.create({
        userId: user.id,
        venueId: request.venueId,
        role: VenueStaffRole.VENUE_ADMIN,
        permissions: adminPermissions,
        jobTitle: request.jobTitle || 'Venue Administrator',
        department: 'Administration',
        createdBy: request.createdBy
      });

      if (!staffResult.success) {
        this.logger.error('Failed to create venue staff record', {
          error: staffResult.error.message,
          venueId: request.venueId,
          userId: user.id,
          correlationId: request.correlationId
        });
        return Result.failure(`Failed to create venue staff record: ${staffResult.error.message}`);
      }

      const venueStaff = staffResult.value;

      this.logger.info('Venue admin provisioned successfully', {
        venueStaffId: venueStaff.id,
        userId: user.id,
        venueId: request.venueId,
        correlationId: request.correlationId
      });

      return Result.success({
        venueStaffId: venueStaff.id,
        userId: user.id,
        venueId: request.venueId,
        role: venueStaff.role,
        status: venueStaff.status,
        createdAt: venueStaff.createdAt
      });

    } catch (error) {
      this.logger.error('Unexpected error provisioning venue admin', {
        error: error instanceof Error ? error.message : String(error),
        request,
        correlationId: request.correlationId
      });

      return Result.failure(`Unexpected error provisioning venue admin: ${
        error instanceof Error ? error.message : String(error)
      }`);
    }
  }

  private validateRequest(request: ProvisionVenueAdminRequest): Result<void, string> {
    if (!request.venueId?.trim()) {
      return Result.failure('Venue ID is required');
    }

    if (!request.adminEmail?.trim()) {
      return Result.failure('Admin email is required');
    }

    if (!request.adminName?.trim()) {
      return Result.failure('Admin name is required');
    }

    if (!request.createdBy?.trim()) {
      return Result.failure('Created by is required');
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(request.adminEmail)) {
      return Result.failure('Invalid email format');
    }

    return Result.success(undefined);
  }

  private async findOrCreateUser(request: ProvisionVenueAdminRequest): Promise<Result<User, string>> {
    // Try to find existing user by email
    const existingUser = await this.userRepository.findByEmail(request.adminEmail);
    
    if (existingUser.success && existingUser.value) {
      // Update user with venue association if needed
      const user = existingUser.value;
      if (!user.venueId) {
        const updateResult = await this.userRepository.updateVenueAssociation(
          user.id, 
          request.venueId
        );
        if (!updateResult.success) {
          return Result.failure(`Failed to update user venue association: ${updateResult.error.message}`);
        }
        return Result.success(updateResult.value);
      }
      return Result.success(user);
    }

    // Create new user
    const createUserResult = await this.userRepository.create({
      email: request.adminEmail,
      name: request.adminName,
      phone: request.adminPhone,
      role: 'user', // Start as regular user, staff role handled separately
      venueId: request.venueId,
      isEmailVerified: false, // Will need to verify
      createdBy: request.createdBy
    });

    if (!createUserResult.success) {
      return Result.failure(`Failed to create user: ${createUserResult.error.message}`);
    }

    return Result.success(createUserResult.value);
  }

  private createVenueAdminPermissions(customPermissions?: Partial<VenueStaffPermissions>): VenueStaffPermissions {
    // Default venue admin permissions (full access to venue operations)
    const defaultPermissions: VenueStaffPermissions = {
      customers: {
        read: true,
        update: true,
        delete: true,
        export: true
      },
      shows: {
        read: true,
        create: true,
        update: true,
        delete: true
      },
      tickets: {
        validate: true,
        refund: true,
        transfer: true,
        comp: true
      },
      analytics: {
        read: true,
        export: true,
        dashboard: true
      },
      staff: {
        read: true,
        invite: true,
        manage: true,
        permissions: true
      },
      venue: {
        settings: true,
        branding: true,
        configuration: true
      }
    };

    // Merge with custom permissions if provided
    if (customPermissions) {
      return {
        customers: { ...defaultPermissions.customers, ...customPermissions.customers },
        shows: { ...defaultPermissions.shows, ...customPermissions.shows },
        tickets: { ...defaultPermissions.tickets, ...customPermissions.tickets },
        analytics: { ...defaultPermissions.analytics, ...customPermissions.analytics },
        staff: { ...defaultPermissions.staff, ...customPermissions.staff },
        venue: { ...defaultPermissions.venue, ...customPermissions.venue }
      };
    }

    return defaultPermissions;
  }
}

/**
 * Supporting types (would normally be imported from shared packages)
 */
export interface User {
  id: string;
  email: string;
  name: string;
  phone?: string;
  role: string;
  venueId?: string;
  isEmailVerified: boolean;
  createdAt: Date;
  updatedAt: Date;
}


