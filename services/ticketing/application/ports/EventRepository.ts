import { Result } from '@thankful/shared';

/**
 * Event Repository Port
 * Handles event data persistence and queries
 */
export interface EventRepository {
  /**
   * Save an event (create or update)
   */
  save(event: Event): Promise<Result<Event, RepositoryError>>;

  /**
   * Find event by ID
   */
  findById(id: string): Promise<Result<Event | null, RepositoryError>>;

  /**
   * Find event by slug
   */
  findBySlug(slug: string): Promise<Result<Event | null, RepositoryError>>;

  /**
   * Find events by venue
   */
  findByVenue(venueId: string): Promise<Result<Event[], RepositoryError>>;

  /**
   * Find events by organizer
   */
  findByOrganizer(organizerId: string): Promise<Result<Event[], RepositoryError>>;

  /**
   * Search events with criteria
   */
  search(criteria: EventSearchCriteria): Promise<Result<EventSearchResult, RepositoryError>>;

  /**
   * Get upcoming events
   */
  findUpcoming(limit?: number): Promise<Result<Event[], RepositoryError>>;

  /**
   * Get featured events
   */
  findFeatured(limit?: number): Promise<Result<Event[], RepositoryError>>;

  /**
   * Get events on sale
   */
  findOnSale(): Promise<Result<Event[], RepositoryError>>;

  /**
   * Update event status
   */
  updateStatus(id: string, status: EventStatus): Promise<Result<void, RepositoryError>>;

  /**
   * Delete event (soft delete)
   */
  delete(id: string): Promise<Result<void, RepositoryError>>;
}

/**
 * Event entity interface
 */
export interface Event {
  id: string;
  venueId: string;
  organizerId: string;
  name: string;
  slug: string;
  description?: string;
  category: EventCategory;
  eventStartTime: Date;
  eventEndTime?: Date;
  doorsOpenTime?: Date;
  timezone: string;
  saleStartTime: Date;
  saleEndTime?: Date;
  presaleStartTime?: Date;
  totalCapacity: number;
  maxTicketsPerUser: number;
  ageRestriction?: number;
  requiresIdVerification: boolean;
  isSeatedEvent: boolean;
  status: EventStatus;
  imageUrl?: string;
  bannerImageUrl?: string;
  metaDescription?: string;
  tags: string[];
  isPublished: boolean;
  isFeatured: boolean;
  createdAt: Date;
  updatedAt: Date;
  publishedAt?: Date;
  cancelledAt?: Date;
}

/**
 * Event categories
 */
export enum EventCategory {
  CONCERT = 'concert',
  SPORTS = 'sports',
  THEATER = 'theater',
  CONFERENCE = 'conference',
  COMEDY = 'comedy',
  FESTIVAL = 'festival',
  EXHIBITION = 'exhibition',
  OTHER = 'other'
}

/**
 * Event statuses (FSM states)
 */
export enum EventStatus {
  DRAFT = 'draft',
  PUBLISHED = 'published',
  ON_SALE = 'on_sale',
  SOLD_OUT = 'sold_out',
  CANCELLED = 'cancelled',
  POSTPONED = 'postponed',
  COMPLETED = 'completed'
}

/**
 * Event search criteria
 */
export interface EventSearchCriteria {
  query?: string; // Text search in name, description
  category?: EventCategory;
  venueId?: string;
  organizerId?: string;
  city?: string;
  startDate?: Date;
  endDate?: Date;
  status?: EventStatus;
  isPublished?: boolean;
  isFeatured?: boolean;
  tags?: string[];
  minPrice?: number;
  maxPrice?: number;
  page?: number;
  limit?: number;
  sortBy?: 'event_start_time' | 'created_at' | 'name' | 'popularity';
  sortOrder?: 'asc' | 'desc';
}

/**
 * Event search result
 */
export interface EventSearchResult {
  events: Event[];
  total: number;
  page: number;
  pages: number;
  hasNext: boolean;
  hasPrev: boolean;
  facets?: EventSearchFacets;
}

/**
 * Search facets for filtering
 */
export interface EventSearchFacets {
  categories: Array<{ category: EventCategory; count: number }>;
  cities: Array<{ city: string; count: number }>;
  priceRanges: Array<{ range: string; count: number }>;
  venues: Array<{ venueId: string; venueName: string; count: number }>;
}

/**
 * Repository error interface
 */
export interface RepositoryError {
  type: 'CONNECTION_ERROR' | 'CONSTRAINT_VIOLATION' | 'NOT_FOUND' | 'TIMEOUT' | 'UNKNOWN';
  message: string;
  code?: string;
  details?: Record<string, any>;
}

/**
 * Helper to create repository errors
 */
export const RepositoryError = {
  connectionError: (message: string, details?: Record<string, any>): RepositoryError => ({
    type: 'CONNECTION_ERROR',
    message,
    details,
  }),

  constraintViolation: (message: string, code?: string, details?: Record<string, any>): RepositoryError => ({
    type: 'CONSTRAINT_VIOLATION',
    message,
    code,
    details,
  }),

  notFound: (message: string): RepositoryError => ({
    type: 'NOT_FOUND',
    message,
  }),

  timeout: (message: string): RepositoryError => ({
    type: 'TIMEOUT',
    message,
  }),

  unknown: (message: string, details?: Record<string, any>): RepositoryError => ({
    type: 'UNKNOWN',
    message,
    details,
  }),
};
