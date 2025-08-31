import { Result } from '@thankful/result';
import { Logger } from '@thankful/logging';
import { VenueStaffRepository } from '../ports/VenueStaffRepository.js';
import { VenueShowRepository } from '../ports/VenueShowRepository.js';
import { DomainEventPublisher } from '@thankful/events';

/**
 * Generic venue show management use case
 * Handles show operations for any venue
 */
export interface GetVenueShowsRequest {
  venueId: string;
  requesterId: string;
  options?: ShowQueryOptions;
  correlationId?: string;
}

export interface AddShowPerformanceRequest {
  venueId: string;
  showId: string;
  performanceDateTime: Date;
  doorsOpenDateTime?: Date;
  performanceNotes?: string;
  pricingOverrides?: PerformancePricingOverride[];
  requesterId: string;
  correlationId?: string;
}

export interface ShowQueryOptions {
  limit?: number;
  offset?: number;
  includeUpcoming?: boolean;
  includePast?: boolean;
  sortBy?: 'created_at' | 'next_performance' | 'title';
  sortOrder?: 'asc' | 'desc';
}

export interface PerformancePricingOverride {
  priceTierCode: string;
  newPriceMinor: number;
  reason?: string;
}

export interface GetVenueShowsResponse {
  shows: VenueShow[];
  total: number;
  hasMore: boolean;
}

export interface AddShowPerformanceResponse {
  performanceId: string;
  showId: string;
  performanceDateTime: Date;
  doorsOpenDateTime?: Date;
  createdAt: Date;
}

export interface VenueShow {
  id: string;
  venueId: string;
  title: string;
  description?: string;
  posterUrl?: string;
  totalSeats: number;
  seatmapId?: string;
  priceTiers: PriceTier[];
  nextPerformance?: Performance;
  upcomingPerformances: Performance[];
  totalPerformances: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface Performance {
  id: string;
  showId: string;
  performanceDateTime: Date;
  doorsOpenDateTime?: Date;
  status: PerformanceStatus;
  availableSeats: number;
  soldSeats: number;
  heldSeats: number;
  performanceNotes?: string;
  pricingOverrides?: PerformancePricingOverride[];
  createdAt: Date;
}

export interface PriceTier {
  code: string;
  name: string;
  amountMinor: number;
  currency: string;
  color: string;
  description?: string;
}

export enum PerformanceStatus {
  SCHEDULED = 'scheduled',
  ON_SALE = 'on_sale',
  SOLD_OUT = 'sold_out',
  CANCELLED = 'cancelled',
  COMPLETED = 'completed'
}

export class ManageVenueShows {
  private readonly logger: Logger;

  constructor(
    private readonly venueStaffRepository: VenueStaffRepository,
    private readonly venueShowRepository: VenueShowRepository,
    private readonly eventPublisher: DomainEventPublisher,
    logger?: Logger
  ) {
    this.logger = logger || new Logger({ service: 'manage-venue-shows' });
  }

  /**
   * Get all shows for a venue
   */
  async getVenueShows(
    request: GetVenueShowsRequest
  ): Promise<Result<GetVenueShowsResponse, string>> {
    try {
      this.logger.info('Getting venue shows', {
        venueId: request.venueId,
        requesterId: request.requesterId,
        correlationId: request.correlationId
      });

      // Verify requester has access to this venue
      const accessCheck = await this.verifyVenueAccess(request.requesterId, request.venueId, 'shows', 'read');
      if (!accessCheck.success) {
        return Result.failure(`Access denied: ${accessCheck.error}`);
      }

      // Get shows from repository
      const showsResult = await this.venueShowRepository.findByVenue(request.venueId, request.options);
      if (!showsResult.success) {
        return Result.failure(`Failed to retrieve venue shows: ${showsResult.error}`);
      }

      this.logger.debug('Retrieved venue shows', {
        venueId: request.venueId,
        showCount: showsResult.value.shows.length,
        correlationId: request.correlationId
      });

      return Result.success({
        shows: showsResult.value.shows,
        total: showsResult.value.total,
        hasMore: showsResult.value.hasMore
      });

    } catch (error) {
      this.logger.error('Unexpected error getting venue shows', {
        error: error instanceof Error ? error.message : String(error),
        request,
        correlationId: request.correlationId
      });

      return Result.failure(`Unexpected error getting venue shows: ${
        error instanceof Error ? error.message : String(error)
      }`);
    }
  }

  /**
   * Add a new performance date to existing show
   */
  async addShowPerformance(
    request: AddShowPerformanceRequest
  ): Promise<Result<AddShowPerformanceResponse, string>> {
    try {
      this.logger.info('Adding show performance', {
        venueId: request.venueId,
        showId: request.showId,
        performanceDateTime: request.performanceDateTime,
        requesterId: request.requesterId,
        correlationId: request.correlationId
      });

      // Validate request
      const validation = this.validateAddPerformanceRequest(request);
      if (!validation.success) {
        return validation;
      }

      // Verify requester has permission to create performances
      const accessCheck = await this.verifyVenueAccess(request.requesterId, request.venueId, 'shows', 'create');
      if (!accessCheck.success) {
        return Result.failure(`Access denied: ${accessCheck.error}`);
      }

      // Verify show exists and belongs to venue
      const showResult = await this.venueShowRepository.findById(request.showId);
      if (!showResult.success || !showResult.value) {
        return Result.failure('Show not found');
      }

      const show = showResult.value;
      if (show.venueId !== request.venueId) {
        return Result.failure('Show does not belong to this venue');
      }

      // Check for conflicting performances
      const conflictCheck = await this.checkPerformanceConflicts(
        request.venueId, 
        request.performanceDateTime
      );
      if (!conflictCheck.success) {
        return Result.failure(`Performance conflict: ${conflictCheck.error}`);
      }

      // Create new performance
      const performance = await this.venueShowRepository.createPerformance({
        showId: request.showId,
        venueId: request.venueId,
        performanceDateTime: request.performanceDateTime,
        doorsOpenDateTime: request.doorsOpenDateTime || this.calculateDoorsOpenTime(request.performanceDateTime),
        performanceNotes: request.performanceNotes,
        pricingOverrides: request.pricingOverrides,
        createdBy: request.requesterId
      });

      if (!performance.success) {
        return Result.failure(`Failed to create performance: ${performance.error}`);
      }

      const newPerformance = performance.value;

      this.logger.info('Show performance added successfully', {
        performanceId: newPerformance.id,
        showId: request.showId,
        venueId: request.venueId,
        performanceDateTime: request.performanceDateTime,
        correlationId: request.correlationId
      });

      return Result.success({
        performanceId: newPerformance.id,
        showId: request.showId,
        performanceDateTime: newPerformance.performanceDateTime,
        doorsOpenDateTime: newPerformance.doorsOpenDateTime,
        createdAt: newPerformance.createdAt
      });

    } catch (error) {
      this.logger.error('Unexpected error adding show performance', {
        error: error instanceof Error ? error.message : String(error),
        request,
        correlationId: request.correlationId
      });

      return Result.failure(`Unexpected error adding show performance: ${
        error instanceof Error ? error.message : String(error)
      }`);
    }
  }

  private async verifyVenueAccess(
    userId: string, 
    venueId: string, 
    resource: string, 
    action: string
  ): Promise<Result<void, string>> {
    const staffResult = await this.venueStaffRepository.findByUserAndVenue(userId, venueId);
    
    if (!staffResult.success || !staffResult.value) {
      return Result.failure('User is not staff member for this venue');
    }

    const staff = staffResult.value;
    
    if (staff.status !== 'active') {
      return Result.failure('Staff member is not active');
    }

    // Check specific permission
    const hasPermission = this.checkPermission(staff.permissions, resource, action);
    if (!hasPermission) {
      return Result.failure(`Staff member does not have ${action} permission for ${resource}`);
    }

    return Result.success(undefined);
  }

  private checkPermission(permissions: any, resource: string, action: string): boolean {
    const resourcePermissions = permissions[resource];
    if (!resourcePermissions) {
      return false;
    }
    
    return resourcePermissions[action] === true;
  }

  private validateAddPerformanceRequest(request: AddShowPerformanceRequest): Result<void, string> {
    if (!request.venueId?.trim()) {
      return Result.failure('Venue ID is required');
    }

    if (!request.showId?.trim()) {
      return Result.failure('Show ID is required');
    }

    if (!request.performanceDateTime) {
      return Result.failure('Performance date and time is required');
    }

    if (!request.requesterId?.trim()) {
      return Result.failure('Requester ID is required');
    }

    // Validate performance is in the future
    if (request.performanceDateTime <= new Date()) {
      return Result.failure('Performance must be scheduled for future date');
    }

    // Validate doors open time if provided
    if (request.doorsOpenDateTime && request.doorsOpenDateTime >= request.performanceDateTime) {
      return Result.failure('Doors open time must be before performance time');
    }

    return Result.success(undefined);
  }

  private async checkPerformanceConflicts(
    venueId: string, 
    performanceDateTime: Date
  ): Promise<Result<void, string>> {
    // Check if there's another performance within 4 hours
    const conflictWindow = 4 * 60 * 60 * 1000; // 4 hours in milliseconds
    const startTime = new Date(performanceDateTime.getTime() - conflictWindow);
    const endTime = new Date(performanceDateTime.getTime() + conflictWindow);

    const conflictingPerformances = await this.venueShowRepository.findPerformancesInTimeWindow(
      venueId, 
      startTime, 
      endTime
    );

    if (conflictingPerformances.success && conflictingPerformances.value.length > 0) {
      return Result.failure('Another performance is scheduled within 4 hours of this time');
    }

    return Result.success(undefined);
  }

  private calculateDoorsOpenTime(performanceDateTime: Date): Date {
    // Default: doors open 1 hour before performance
    return new Date(performanceDateTime.getTime() - (60 * 60 * 1000));
  }
}


