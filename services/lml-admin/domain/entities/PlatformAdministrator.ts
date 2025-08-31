import { AggregateRoot, Result } from '@thankful/shared';
import { AdminRole } from '../valueobjects/AdminRole.js';
import { AdminPermissions } from '../valueobjects/AdminPermissions.js';
import { PlatformAdministratorCreatedEvent } from '../events/PlatformAdministratorCreatedEvent.js';
import { PlatformAdministratorStatusChangedEvent } from '../events/PlatformAdministratorStatusChangedEvent.js';

/**
 * Platform Administrator aggregate root for LML Admin bounded context
 * Manages LML employee accounts with platform-level access
 */
export class PlatformAdministrator extends AggregateRoot<string> {
  private constructor(
    id: string,
    private readonly _userId: string,
    private _role: AdminRole,
    private _permissions: AdminPermissions,
    private _isActive: boolean,
    private readonly _createdAt: Date,
    private readonly _createdBy: string | undefined,
    private _updatedAt: Date,
    private _lastLoginAt: Date | undefined
  ) {
    super(id);
  }

  /**
   * Create a new platform administrator
   */
  public static create(
    id: string,
    userId: string,
    role: AdminRole,
    permissions: AdminPermissions,
    createdBy?: string
  ): Result<PlatformAdministrator, string> {
    if (!userId.trim()) {
      return Result.failure('User ID is required');
    }

    const administrator = new PlatformAdministrator(
      id,
      userId,
      role,
      permissions,
      true, // Active by default
      new Date(),
      createdBy,
      new Date(),
      undefined
    );

    // Emit domain event
    administrator.addDomainEvent(new PlatformAdministratorCreatedEvent(id, {
      userId,
      role: role.value,
      permissions: permissions.toJSON(),
      createdBy,
      createdAt: new Date()
    }));

    return Result.success(administrator);
  }

  /**
   * Update administrator role
   */
  public updateRole(
    newRole: AdminRole,
    updatedBy: string
  ): Result<void, string> {
    if (!this._isActive) {
      return Result.failure('Cannot update role of inactive administrator');
    }

    const previousRole = this._role;
    this._role = newRole;
    this._updatedAt = new Date();

    this.addDomainEvent(new PlatformAdministratorStatusChangedEvent(this.id, {
      userId: this._userId,
      previousRole: previousRole.value,
      newRole: newRole.value,
      changedBy: updatedBy,
      changedAt: this._updatedAt,
      reason: 'role_updated'
    }));

    return Result.success(undefined);
  }

  /**
   * Update administrator permissions
   */
  public updatePermissions(
    newPermissions: AdminPermissions,
    updatedBy: string
  ): Result<void, string> {
    if (!this._isActive) {
      return Result.failure('Cannot update permissions of inactive administrator');
    }

    this._permissions = newPermissions;
    this._updatedAt = new Date();

    return Result.success(undefined);
  }

  /**
   * Activate administrator
   */
  public activate(activatedBy: string): Result<void, string> {
    if (this._isActive) {
      return Result.failure('Administrator is already active');
    }

    this._isActive = true;
    this._updatedAt = new Date();

    this.addDomainEvent(new PlatformAdministratorStatusChangedEvent(this.id, {
      userId: this._userId,
      previousRole: this._role.value,
      newRole: this._role.value,
      changedBy: activatedBy,
      changedAt: this._updatedAt,
      reason: 'administrator_activated'
    }));

    return Result.success(undefined);
  }

  /**
   * Deactivate administrator
   */
  public deactivate(deactivatedBy: string): Result<void, string> {
    if (!this._isActive) {
      return Result.failure('Administrator is already inactive');
    }

    this._isActive = false;
    this._updatedAt = new Date();

    this.addDomainEvent(new PlatformAdministratorStatusChangedEvent(this.id, {
      userId: this._userId,
      previousRole: this._role.value,
      newRole: this._role.value,
      changedBy: deactivatedBy,
      changedAt: this._updatedAt,
      reason: 'administrator_deactivated'
    }));

    return Result.success(undefined);
  }

  /**
   * Record login
   */
  public recordLogin(): void {
    this._lastLoginAt = new Date();
  }

  /**
   * Business logic methods
   */
  public canManageVenues(): boolean {
    return this._isActive && this._permissions.hasVenuePermission('manage');
  }

  public canViewPlatformAnalytics(): boolean {
    return this._isActive && this._permissions.hasPlatformPermission('analytics');
  }

  public canManageBilling(): boolean {
    return this._isActive && this._permissions.hasPlatformPermission('billing');
  }

  public canAccessEmergencyMode(): boolean {
    return this._isActive && 
           this._role === AdminRole.SUPER_ADMIN && 
           this._permissions.hasPlatformPermission('emergency_access');
  }

  public canManageAdministrators(): boolean {
    return this._isActive && 
           this._role === AdminRole.SUPER_ADMIN &&
           this._permissions.hasSystemPermission('user_management');
  }

  public hasPermission(
    category: 'venue' | 'platform' | 'system',
    permission: string
  ): boolean {
    if (!this._isActive) {
      return false;
    }

    switch (category) {
      case 'venue':
        return this._permissions.hasVenuePermission(permission);
      case 'platform':
        return this._permissions.hasPlatformPermission(permission);
      case 'system':
        return this._permissions.hasSystemPermission(permission);
      default:
        return false;
    }
  }

  /**
   * Getters
   */
  public get userId(): string {
    return this._userId;
  }

  public get role(): AdminRole {
    return this._role;
  }

  public get permissions(): AdminPermissions {
    return this._permissions;
  }

  public get isActive(): boolean {
    return this._isActive;
  }

  public get createdAt(): Date {
    return this._createdAt;
  }

  public get createdBy(): string | undefined {
    return this._createdBy;
  }

  public get updatedAt(): Date {
    return this._updatedAt;
  }

  public get lastLoginAt(): Date | undefined {
    return this._lastLoginAt;
  }

  /**
   * Compatibility methods for application layer
   */
  public getId(): string {
    return this.id;
  }

  public getUserId(): string {
    return this._userId;
  }

  public getRole(): string {
    return this._role.value;
  }

  public getPermissions(): Record<string, any> {
    return this._permissions.toJSON();
  }

  public getIsActive(): boolean {
    return this._isActive;
  }

  public getCreatedAt(): Date {
    return this._createdAt;
  }

  public getUpdatedAt(): Date {
    return this._updatedAt;
  }
}

