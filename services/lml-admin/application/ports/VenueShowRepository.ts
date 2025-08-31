import { Result } from '@thankful/result';
import { RepositoryError } from './VenueAccountRepository.js';
import { VenueShow, Performance, ShowQueryOptions, PerformancePricingOverride } from '../usecases/ManageVenueShows.js';

/**
 * Generic Venue Show Repository Port
 * Handles show and performance data for any venue
 */
export interface VenueShowRepository {
  /**
   * Find show by ID
   */
  findById(showId: string): Promise<Result<VenueShow | null, string>>;

  /**
   * Find all shows for a venue
   */
  findByVenue(venueId: string, options?: ShowQueryOptions): Promise<Result<VenueShowResult, string>>;

  /**
   * Create a new performance for existing show
   */
  createPerformance(performanceData: CreatePerformanceData): Promise<Result<Performance, string>>;

  /**
   * Find performances in time window (for conflict checking)
   */
  findPerformancesInTimeWindow(
    venueId: string, 
    startTime: Date, 
    endTime: Date
  ): Promise<Result<Performance[], string>>;

  /**
   * Get performance by ID
   */
  findPerformanceById(performanceId: string): Promise<Result<Performance | null, string>>;

  /**
   * Update performance
   */
  updatePerformance(performanceId: string, updates: UpdatePerformanceData): Promise<Result<Performance, string>>;

  /**
   * Cancel performance
   */
  cancelPerformance(performanceId: string, cancelledBy: string, reason: string): Promise<Result<void, string>>;

  /**
   * Get upcoming performances for venue
   */
  getUpcomingPerformances(venueId: string, limit?: number): Promise<Result<Performance[], string>>;

  /**
   * Link existing show data to venue (for migration)
   */
  linkExistingShow(linkData: LinkExistingShowData): Promise<Result<VenueShow, string>>;

  /**
   * Get show statistics
   */
  getShowStats(showId: string): Promise<Result<ShowStatistics, string>>;
}

/**
 * Data structures
 */
export interface VenueShowResult {
  shows: VenueShow[];
  total: number;
  hasMore: boolean;
}

export interface CreatePerformanceData {
  showId: string;
  venueId: string;
  performanceDateTime: Date;
  doorsOpenDateTime?: Date;
  performanceNotes?: string;
  pricingOverrides?: PerformancePricingOverride[];
  createdBy: string;
}

export interface UpdatePerformanceData {
  performanceDateTime?: Date;
  doorsOpenDateTime?: Date;
  performanceNotes?: string;
  pricingOverrides?: PerformancePricingOverride[];
  updatedBy: string;
}

export interface LinkExistingShowData {
  existingShowId: string;
  existingPerformanceId?: string;
  venueId: string;
  linkedBy: string;
}

export interface ShowStatistics {
  showId: string;
  totalPerformances: number;
  totalTicketsSold: number;
  totalRevenue: number;
  averageAttendance: number;
  upcomingPerformances: number;
  lastPerformanceDate?: Date;
  nextPerformanceDate?: Date;
  popularPriceTiers: PriceTierStats[];
}

export interface PriceTierStats {
  priceTierCode: string;
  ticketsSold: number;
  revenue: number;
  averagePrice: number;
}
