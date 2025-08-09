import { Result } from '@thankful/shared';
import { EventRepository, Event, EventCategory, EventStatus, RepositoryError } from '../ports/EventRepository.js';

/**
 * Create Event Use Case
 * Handles event creation with validation and business rules
 */
export class CreateEvent {
  constructor(private eventRepository: EventRepository) {}

  /**
   * Execute event creation
   */
  async execute(command: CreateEventCommand): Promise<Result<EventCreationResult, EventCreationError>> {
    // Validate command
    const validationResult = this.validateCommand(command);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error);
    }

    // Generate slug from event name
    const slug = this.generateSlug(command.name);

    // Check if slug already exists
    const existingEventResult = await this.eventRepository.findBySlug(slug);
    if (existingEventResult.isFailure) {
      return Result.failure(EventCreationError.repositoryError(existingEventResult.error.message));
    }

    if (existingEventResult.value) {
      return Result.failure(EventCreationError.slugAlreadyExists(`Event with slug "${slug}" already exists`));
    }

    // Create event entity
    const event: Event = {
      id: this.generateId(),
      venueId: command.venueId,
      organizerId: command.organizerId,
      name: command.name,
      slug,
      description: command.description,
      category: command.category,
      eventStartTime: command.eventStartTime,
      eventEndTime: command.eventEndTime,
      doorsOpenTime: command.doorsOpenTime,
      timezone: command.timezone || 'UTC',
      saleStartTime: command.saleStartTime,
      saleEndTime: command.saleEndTime,
      presaleStartTime: command.presaleStartTime,
      totalCapacity: command.totalCapacity,
      maxTicketsPerUser: command.maxTicketsPerUser || 8,
      ageRestriction: command.ageRestriction,
      requiresIdVerification: command.requiresIdVerification || false,
      isSeatedEvent: command.isSeatedEvent ?? true,
      status: EventStatus.DRAFT,
      imageUrl: command.imageUrl,
      bannerImageUrl: command.bannerImageUrl,
      metaDescription: command.metaDescription,
      tags: command.tags || [],
      isPublished: false,
      isFeatured: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    // Save event
    const saveResult = await this.eventRepository.save(event);
    if (saveResult.isFailure) {
      return Result.failure(EventCreationError.repositoryError(saveResult.error.message));
    }

    const savedEvent = saveResult.value;

    // Return result
    const result: EventCreationResult = {
      eventId: savedEvent.id,
      slug: savedEvent.slug,
      name: savedEvent.name,
      category: savedEvent.category,
      eventStartTime: savedEvent.eventStartTime,
      status: savedEvent.status,
      totalCapacity: savedEvent.totalCapacity,
      isSeatedEvent: savedEvent.isSeatedEvent,
      createdAt: savedEvent.createdAt,
      nextSteps: this.getNextSteps(savedEvent),
    };

    return Result.success(result);
  }

  /**
   * Validate the create event command
   */
  private validateCommand(command: CreateEventCommand): Result<void, EventCreationError> {
    const errors: string[] = [];

    // Required fields
    if (!command.name?.trim()) {
      errors.push('Event name is required');
    }
    if (!command.venueId) {
      errors.push('Venue ID is required');
    }
    if (!command.organizerId) {
      errors.push('Organizer ID is required');
    }
    if (!command.eventStartTime) {
      errors.push('Event start time is required');
    }
    if (!command.saleStartTime) {
      errors.push('Sale start time is required');
    }
    if (!command.totalCapacity || command.totalCapacity <= 0) {
      errors.push('Total capacity must be greater than 0');
    }

    // Date validations
    if (command.eventStartTime && command.saleStartTime) {
      if (command.eventStartTime <= command.saleStartTime) {
        errors.push('Event start time must be after sale start time');
      }
    }

    if (command.eventEndTime && command.eventStartTime) {
      if (command.eventEndTime <= command.eventStartTime) {
        errors.push('Event end time must be after start time');
      }
    }

    if (command.doorsOpenTime && command.eventStartTime) {
      if (command.doorsOpenTime >= command.eventStartTime) {
        errors.push('Doors open time must be before event start time');
      }
    }

    if (command.presaleStartTime && command.saleStartTime) {
      if (command.presaleStartTime >= command.saleStartTime) {
        errors.push('Presale start time must be before main sale start time');
      }
    }

    // Business rules
    if (command.maxTicketsPerUser && (command.maxTicketsPerUser < 1 || command.maxTicketsPerUser > 50)) {
      errors.push('Max tickets per user must be between 1 and 50');
    }

    if (command.ageRestriction && (command.ageRestriction < 0 || command.ageRestriction > 99)) {
      errors.push('Age restriction must be between 0 and 99');
    }

    if (command.name && command.name.length > 200) {
      errors.push('Event name must be 200 characters or less');
    }

    if (command.description && command.description.length > 5000) {
      errors.push('Event description must be 5000 characters or less');
    }

    if (errors.length > 0) {
      return Result.failure(EventCreationError.validationError('Event validation failed', errors));
    }

    return Result.success(undefined);
  }

  /**
   * Generate URL-friendly slug from event name
   */
  private generateSlug(name: string): string {
    return name
      .toLowerCase()
      .trim()
      .replace(/[^\w\s-]/g, '') // Remove special chars
      .replace(/\s+/g, '-') // Replace spaces with hyphens
      .replace(/-+/g, '-') // Remove multiple hyphens
      .replace(/^-|-$/g, ''); // Remove leading/trailing hyphens
  }

  /**
   * Generate unique ID (simplified - would use proper UUID in real implementation)
   */
  private generateId(): string {
    return `event_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Get next steps for event creation
   */
  private getNextSteps(event: Event): string[] {
    const steps: string[] = [];

    steps.push('Configure pricing tiers');
    
    if (event.isSeatedEvent) {
      steps.push('Set up seat assignments');
    }

    steps.push('Upload event images');
    steps.push('Review and publish event');

    return steps;
  }
}

/**
 * Create event command
 */
export interface CreateEventCommand {
  venueId: string;
  organizerId: string;
  name: string;
  description?: string;
  category: EventCategory;
  eventStartTime: Date;
  eventEndTime?: Date;
  doorsOpenTime?: Date;
  timezone?: string;
  saleStartTime: Date;
  saleEndTime?: Date;
  presaleStartTime?: Date;
  totalCapacity: number;
  maxTicketsPerUser?: number;
  ageRestriction?: number;
  requiresIdVerification?: boolean;
  isSeatedEvent?: boolean;
  imageUrl?: string;
  bannerImageUrl?: string;
  metaDescription?: string;
  tags?: string[];
}

/**
 * Event creation result
 */
export interface EventCreationResult {
  eventId: string;
  slug: string;
  name: string;
  category: EventCategory;
  eventStartTime: Date;
  status: EventStatus;
  totalCapacity: number;
  isSeatedEvent: boolean;
  createdAt: Date;
  nextSteps: string[];
}

/**
 * Event creation error types
 */
export interface EventCreationError {
  type: 'VALIDATION_ERROR' | 'SLUG_ALREADY_EXISTS' | 'VENUE_NOT_FOUND' | 'ORGANIZER_NOT_FOUND' | 'REPOSITORY_ERROR';
  message: string;
  fields?: string[];
  details?: string[];
}

/**
 * Helper to create event creation errors
 */
export const EventCreationError = {
  validationError: (message: string, details: string[]): EventCreationError => ({
    type: 'VALIDATION_ERROR',
    message,
    details,
  }),

  slugAlreadyExists: (message: string): EventCreationError => ({
    type: 'SLUG_ALREADY_EXISTS',
    message,
  }),

  venueNotFound: (message: string): EventCreationError => ({
    type: 'VENUE_NOT_FOUND',
    message,
  }),

  organizerNotFound: (message: string): EventCreationError => ({
    type: 'ORGANIZER_NOT_FOUND',
    message,
  }),

  repositoryError: (message: string): EventCreationError => ({
    type: 'REPOSITORY_ERROR',
    message,
  }),
};
