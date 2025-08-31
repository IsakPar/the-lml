import { AggregateRoot, Result } from '@thankful/shared';
import { VenueAccountId, VenueName, VenueSlug } from '@thankful/shared';
import { VenueAccountStatus } from '../valueobjects/VenueAccountStatus.js';
import { VenueConfiguration } from '../valueobjects/VenueConfiguration.js';
import { BillingConfiguration } from '../valueobjects/BillingConfiguration.js';
import { ContactInformation } from '../valueobjects/ContactInformation.js';
import { VenueAccountCreatedEvent } from '../events/VenueAccountCreatedEvent.js';
import { VenueAccountStatusChangedEvent } from '../events/VenueAccountStatusChangedEvent.js';

/**
 * VenueAccount aggregate root for LML Admin bounded context
 * Manages the lifecycle and configuration of venue accounts on the platform
 */
export class VenueAccount extends AggregateRoot<VenueAccountId> {
  private constructor(
    id: VenueAccountId,
    private readonly _venueName: VenueName,
    private readonly _venueSlug: VenueSlug,
    private readonly _displayName: string,
    private _description: string | undefined,
    private _status: VenueAccountStatus,
    private _configuration: VenueConfiguration,
    private _billingConfiguration: BillingConfiguration,
    private _contactInformation: ContactInformation,
    private readonly _createdAt: Date,
    private readonly _createdBy: string,
    private _updatedAt: Date,
    private _updatedBy: string | undefined,
    private _activatedAt: Date | undefined,
    private _suspendedAt: Date | undefined
  ) {
    super(id);
  }

  /**
   * Create a new venue account
   */
  public static create(
    id: VenueAccountId,
    venueName: VenueName,
    venueSlug: VenueSlug,
    displayName: string,
    description: string | undefined,
    configuration: VenueConfiguration,
    billingConfiguration: BillingConfiguration,
    contactInformation: ContactInformation,
    createdBy: string
  ): Result<VenueAccount, string> {
    // Validate required fields
    if (!displayName.trim()) {
      return Result.failure('Display name cannot be empty');
    }

    if (!createdBy.trim()) {
      return Result.failure('Created by is required');
    }

    const venueAccount = new VenueAccount(
      id,
      venueName,
      venueSlug,
      displayName,
      description,
      VenueAccountStatus.PENDING,
      configuration,
      billingConfiguration,
      contactInformation,
      new Date(),
      createdBy,
      new Date(),
      undefined,
      undefined,
      undefined
    );

    // Emit domain event
    venueAccount.addDomainEvent(new VenueAccountCreatedEvent(id, {
      venueName: venueName.value,
      venueSlug: venueSlug.value,
      displayName,
      status: VenueAccountStatus.PENDING,
      createdBy,
      createdAt: new Date()
    }));

    return Result.success(venueAccount);
  }

  /**
   * Activate the venue account
   */
  public activate(activatedBy: string): Result<void, string> {
    if (this._status === VenueAccountStatus.ACTIVE) {
      return Result.failure('Venue account is already active');
    }

    if (this._status === VenueAccountStatus.ARCHIVED) {
      return Result.failure('Cannot activate archived venue account');
    }

    const previousStatus = this._status;
    this._status = VenueAccountStatus.ACTIVE;
    this._activatedAt = new Date();
    this._updatedAt = new Date();
    this._updatedBy = activatedBy;
    this._suspendedAt = undefined;

    this.addDomainEvent(new VenueAccountStatusChangedEvent(this.id, {
      venueId: this.id,
      previousStatus,
      newStatus: this._status,
      changedBy: activatedBy,
      changedAt: this._updatedAt,
      reason: 'venue_activated'
    }));

    return Result.success(undefined);
  }

  /**
   * Suspend the venue account
   */
  public suspend(suspendedBy: string, reason: string): Result<void, string> {
    if (this._status === VenueAccountStatus.SUSPENDED) {
      return Result.failure('Venue account is already suspended');
    }

    if (this._status === VenueAccountStatus.ARCHIVED) {
      return Result.failure('Cannot suspend archived venue account');
    }

    const previousStatus = this._status;
    this._status = VenueAccountStatus.SUSPENDED;
    this._suspendedAt = new Date();
    this._updatedAt = new Date();
    this._updatedBy = suspendedBy;

    this.addDomainEvent(new VenueAccountStatusChangedEvent(this.id, {
      venueId: this.id,
      previousStatus,
      newStatus: this._status,
      changedBy: suspendedBy,
      changedAt: this._updatedAt,
      reason
    }));

    return Result.success(undefined);
  }

  /**
   * Archive the venue account
   */
  public archive(archivedBy: string): Result<void, string> {
    if (this._status === VenueAccountStatus.ARCHIVED) {
      return Result.failure('Venue account is already archived');
    }

    const previousStatus = this._status;
    this._status = VenueAccountStatus.ARCHIVED;
    this._updatedAt = new Date();
    this._updatedBy = archivedBy;

    this.addDomainEvent(new VenueAccountStatusChangedEvent(this.id, {
      venueId: this.id,
      previousStatus,
      newStatus: this._status,
      changedBy: archivedBy,
      changedAt: this._updatedAt,
      reason: 'venue_archived'
    }));

    return Result.success(undefined);
  }

  /**
   * Update venue configuration
   */
  public updateConfiguration(
    newConfiguration: VenueConfiguration,
    updatedBy: string
  ): Result<void, string> {
    if (this._status === VenueAccountStatus.ARCHIVED) {
      return Result.failure('Cannot update configuration of archived venue');
    }

    this._configuration = newConfiguration;
    this._updatedAt = new Date();
    this._updatedBy = updatedBy;

    return Result.success(undefined);
  }

  /**
   * Update billing configuration
   */
  public updateBillingConfiguration(
    newBillingConfiguration: BillingConfiguration,
    updatedBy: string
  ): Result<void, string> {
    if (this._status === VenueAccountStatus.ARCHIVED) {
      return Result.failure('Cannot update billing of archived venue');
    }

    this._billingConfiguration = newBillingConfiguration;
    this._updatedAt = new Date();
    this._updatedBy = updatedBy;

    return Result.success(undefined);
  }

  /**
   * Update contact information
   */
  public updateContactInformation(
    newContactInformation: ContactInformation,
    updatedBy: string
  ): Result<void, string> {
    this._contactInformation = newContactInformation;
    this._updatedAt = new Date();
    this._updatedBy = updatedBy;

    return Result.success(undefined);
  }

  /**
   * Update description
   */
  public updateDescription(
    newDescription: string | undefined,
    updatedBy: string
  ): void {
    this._description = newDescription;
    this._updatedAt = new Date();
    this._updatedBy = updatedBy;
  }

  /**
   * Business logic methods
   */
  public canBeActivated(): boolean {
    return this._status === VenueAccountStatus.PENDING || 
           this._status === VenueAccountStatus.SUSPENDED;
  }

  public canBeSuspended(): boolean {
    return this._status === VenueAccountStatus.ACTIVE;
  }

  public canBeArchived(): boolean {
    return this._status !== VenueAccountStatus.ARCHIVED;
  }

  public isOperational(): boolean {
    return this._status === VenueAccountStatus.ACTIVE;
  }

  public isAccessible(): boolean {
    return this._status === VenueAccountStatus.ACTIVE || 
           this._status === VenueAccountStatus.SUSPENDED;
  }

  /**
   * Getters
   */
  public get venueName(): VenueName {
    return this._venueName;
  }

  public get venueSlug(): VenueSlug {
    return this._venueSlug;
  }

  public get displayName(): string {
    return this._displayName;
  }

  public get description(): string | undefined {
    return this._description;
  }

  public get status(): VenueAccountStatus {
    return this._status;
  }

  public get configuration(): VenueConfiguration {
    return this._configuration;
  }

  public get billingConfiguration(): BillingConfiguration {
    return this._billingConfiguration;
  }

  public get contactInformation(): ContactInformation {
    return this._contactInformation;
  }

  public get createdAt(): Date {
    return this._createdAt;
  }

  public get createdBy(): string {
    return this._createdBy;
  }

  public get updatedAt(): Date {
    return this._updatedAt;
  }

  public get updatedBy(): string | undefined {
    return this._updatedBy;
  }

  public get activatedAt(): Date | undefined {
    return this._activatedAt;
  }

  public get suspendedAt(): Date | undefined {
    return this._suspendedAt;
  }

  /**
   * Compatibility methods for application layer
   */
  public getId(): string {
    return this.id;
  }

  public getVenueName(): string {
    return this._venueName.value;
  }

  public getVenueSlug(): string {
    return this._venueSlug.value;
  }

  public getDisplayName(): string {
    return this._displayName;
  }

  public getStatus(): string {
    return this._status;
  }

  public getCreatedAt(): Date {
    return this._createdAt;
  }

  public getUpdatedAt(): Date {
    return this._updatedAt;
  }
}

