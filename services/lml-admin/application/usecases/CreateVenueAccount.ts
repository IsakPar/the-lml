import { Result } from '@thankful/result';
import { Logger } from '@thankful/logging';
import { VenueAccount } from '../../domain/entities/VenueAccount.js';
import { VenueConfiguration } from '../../domain/valueobjects/VenueConfiguration.js';
import { BillingConfiguration } from '../../domain/valueobjects/BillingConfiguration.js';
import { ContactInformation, ContactInformationData } from '../../domain/valueobjects/ContactInformation.js';
import { VenueName, VenueSlug } from '@thankful/shared';
import { VenueAccountRepository } from '../ports/VenueAccountRepository.js';
import { DomainEventPublisher } from '@thankful/events';

/**
 * Generic use case to create any venue account
 * Works for Hamilton, Lincoln Center, or any other venue
 */
export interface CreateVenueAccountRequest {
  venueName: string;
  venueSlug: string;
  displayName: string;
  description?: string;
  contactInfo: ContactInformationData;
  venueConfiguration?: VenueConfigurationRequest;
  billingConfiguration?: BillingConfigurationRequest;
  createdBy: string;
  correlationId?: string;
}

export interface VenueConfigurationRequest {
  branding?: {
    logoUrl?: string;
    primaryColor?: string;
    secondaryColor?: string;
    theme?: string;
    customCss?: string;
  };
  features?: {
    ticketValidation?: boolean;
    customerManagement?: boolean;
    analytics?: boolean;
    staffManagement?: boolean;
    mobileApp?: boolean;
    apiAccess?: boolean;
  };
  limits?: {
    maxStaff?: number;
    maxShowsPerMonth?: number;
    maxCustomers?: number;
    maxApiCallsPerMonth?: number;
    maxStorageGb?: number;
    maxConcurrentUsers?: number;
  };
}

export interface BillingConfigurationRequest {
  plan?: string;
  feePercentage?: number;
  monthlyFee?: number;
  transactionFee?: number;
  currency?: string;
}

export interface CreateVenueAccountResponse {
  venueAccountId: string;
  venueName: string;
  venueSlug: string;
  displayName: string;
  status: string;
  createdAt: Date;
}

export class CreateVenueAccount {
  private readonly logger: Logger;

  constructor(
    private readonly venueAccountRepository: VenueAccountRepository,
    private readonly eventPublisher: DomainEventPublisher,
    logger?: Logger
  ) {
    this.logger = logger || new Logger({ service: 'create-venue-account' });
  }

  async execute(
    request: CreateVenueAccountRequest
  ): Promise<Result<CreateVenueAccountResponse, string>> {
    try {
      this.logger.info('Creating venue account', {
        venueName: request.venueName,
        venueSlug: request.venueSlug,
        createdBy: request.createdBy,
        correlationId: request.correlationId
      });

      // Validate input
      const validation = this.validateRequest(request);
      if (!validation.success) {
        return validation;
      }

      // Check if venue slug already exists
      const existingVenue = await this.venueAccountRepository.findBySlug(request.venueSlug);
      if (existingVenue.success && existingVenue.value) {
        return Result.failure(`Venue with slug '${request.venueSlug}' already exists`);
      }

      // Create venue name and slug value objects
      const venueNameResult = VenueName.create(request.venueName);
      const venueSlugResult = VenueSlug.create(request.venueSlug);

      if (!venueNameResult.success) {
        return Result.failure(`Invalid venue name: ${venueNameResult.error}`);
      }

      if (!venueSlugResult.success) {
        return Result.failure(`Invalid venue slug: ${venueSlugResult.error}`);
      }

      // Create venue configuration
      const configurationResult = this.createVenueConfiguration(request.venueConfiguration);
      if (!configurationResult.success) {
        return Result.failure(`Failed to create venue configuration: ${configurationResult.error}`);
      }

      // Create billing configuration
      const billingConfiguration = this.createBillingConfiguration(request.billingConfiguration);

      // Create contact information
      const contactInfoResult = ContactInformation.create(request.contactInfo);
      if (!contactInfoResult.success) {
        return Result.failure(`Invalid contact information: ${contactInfoResult.error}`);
      }

      // Generate venue ID
      const venueId = `${request.venueSlug}-venue-${Date.now()}`;

      // Create venue account domain entity
      const venueAccountResult = VenueAccount.create(
        venueId,
        venueNameResult.value,
        venueSlugResult.value,
        request.displayName,
        request.description,
        configurationResult.value,
        billingConfiguration,
        contactInfoResult.value,
        request.createdBy
      );

      if (!venueAccountResult.success) {
        return Result.failure(`Failed to create venue account: ${venueAccountResult.error}`);
      }

      const venueAccount = venueAccountResult.value;

      // Save venue account
      const saveResult = await this.venueAccountRepository.save(venueAccount);
      if (!saveResult.success) {
        this.logger.error('Failed to save venue account', {
          error: saveResult.error.message,
          venueId,
          correlationId: request.correlationId
        });
        return Result.failure(`Failed to save venue account: ${saveResult.error.message}`);
      }

      // Publish domain events
      const events = venueAccount.getUncommittedEvents();
      for (const event of events) {
        await this.eventPublisher.publish(event);
      }
      venueAccount.markEventsAsCommitted();

      this.logger.info('Venue account created successfully', {
        venueAccountId: venueAccount.getId(),
        venueName: venueAccount.getVenueName(),
        venueSlug: venueAccount.getVenueSlug(),
        correlationId: request.correlationId
      });

      return Result.success({
        venueAccountId: venueAccount.getId(),
        venueName: venueAccount.getVenueName(),
        venueSlug: venueAccount.getVenueSlug(),
        displayName: venueAccount.getDisplayName(),
        status: venueAccount.getStatus(),
        createdAt: venueAccount.getCreatedAt()
      });

    } catch (error) {
      this.logger.error('Unexpected error creating venue account', {
        error: error instanceof Error ? error.message : String(error),
        request,
        correlationId: request.correlationId
      });

      return Result.failure(`Unexpected error creating venue account: ${
        error instanceof Error ? error.message : String(error)
      }`);
    }
  }

  private validateRequest(request: CreateVenueAccountRequest): Result<void, string> {
    if (!request.venueName?.trim()) {
      return Result.failure('Venue name is required');
    }

    if (!request.venueSlug?.trim()) {
      return Result.failure('Venue slug is required');
    }

    if (!request.displayName?.trim()) {
      return Result.failure('Display name is required');
    }

    if (!request.createdBy?.trim()) {
      return Result.failure('Created by is required');
    }

    if (!request.contactInfo?.primaryContact?.name) {
      return Result.failure('Primary contact name is required');
    }

    if (!request.contactInfo?.primaryContact?.email) {
      return Result.failure('Primary contact email is required');
    }

    if (!request.contactInfo?.primaryContact?.phone) {
      return Result.failure('Primary contact phone is required');
    }

    return Result.success(undefined);
  }

  private createVenueConfiguration(
    config?: VenueConfigurationRequest
  ): Result<VenueConfiguration, string> {
    // Start with default configuration
    let venueConfig = VenueConfiguration.createDefault();

    if (!config) {
      return Result.success(venueConfig);
    }

    // Update branding if provided
    if (config.branding) {
      const brandingResult = venueConfig.updateBranding({
        logoUrl: config.branding.logoUrl,
        primaryColor: config.branding.primaryColor || '#000000',
        secondaryColor: config.branding.secondaryColor || '#ffffff',
        theme: config.branding.theme as any || 'default',
        customCss: config.branding.customCss
      });

      if (!brandingResult.success) {
        return brandingResult;
      }
      venueConfig = brandingResult.value;
    }

    // Update features if provided
    if (config.features) {
      venueConfig = venueConfig.updateFeatures(config.features);
    }

    // Update limits if provided
    if (config.limits) {
      const limitsResult = venueConfig.updateLimits(config.limits);
      if (!limitsResult.success) {
        return limitsResult;
      }
      venueConfig = limitsResult.value;
    }

    return Result.success(venueConfig);
  }

  private createBillingConfiguration(
    config?: BillingConfigurationRequest
  ): BillingConfiguration {
    if (!config) {
      return BillingConfiguration.createDefault();
    }

    const defaultConfig = BillingConfiguration.createDefault();
    
    // Update with provided values
    if (config.feePercentage || config.monthlyFee || config.transactionFee || config.currency) {
      const pricingUpdate = defaultConfig.updatePricing({
        feePercentage: config.feePercentage,
        monthlyFee: config.monthlyFee,
        transactionFee: config.transactionFee,
        currency: config.currency
      });

      if (pricingUpdate.success) {
        return pricingUpdate.value;
      }
    }

    return defaultConfig;
  }
}


