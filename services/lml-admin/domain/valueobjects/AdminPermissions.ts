import { Result } from '@thankful/result';
import { AdminPermissionsData } from './AdminRole.js';

/**
 * Admin Permissions value object
 * Encapsulates all permissions for platform administrators
 */
export interface VenuePermissions {
  create?: boolean;
  read?: boolean;
  update?: boolean;
  delete?: boolean;
  suspend?: boolean;
  archive?: boolean;
  billing?: boolean;
}

export interface PlatformPermissions {
  analytics?: boolean;
  billing?: boolean;
  system_config?: boolean;
  emergency_access?: boolean;
  maintenance_mode?: boolean;
  feature_flags?: boolean;
}

export interface SystemPermissions {
  user_management?: boolean;
  role_management?: boolean;
  permission_management?: boolean;
  audit_logs?: boolean;
  system_health?: boolean;
  backup_restore?: boolean;
}

export class AdminPermissions {
  private constructor(
    private readonly _venuePermissions: VenuePermissions,
    private readonly _platformPermissions: PlatformPermissions,
    private readonly _systemPermissions: SystemPermissions
  ) {}

  public static create(data: AdminPermissionsData): Result<AdminPermissions, string> {
    const validation = AdminPermissions.validate(data);
    if (!validation.success) {
      return validation;
    }

    return Result.success(new AdminPermissions(
      data.venues || {},
      data.platform || {},
      data.system || {}
    ));
  }

  public static createDefault(): AdminPermissions {
    const defaultData: AdminPermissionsData = {
      venues: {},
      platform: {},
      system: {}
    };

    return new AdminPermissions(
      defaultData.venues,
      defaultData.platform,
      defaultData.system
    );
  }

  public static createSuperAdminPermissions(): AdminPermissions {
    const superAdminData: AdminPermissionsData = {
      venues: {
        create: true,
        read: true,
        update: true,
        delete: true,
        suspend: true,
        archive: true,
        billing: true
      },
      platform: {
        analytics: true,
        billing: true,
        system_config: true,
        emergency_access: true,
        maintenance_mode: true,
        feature_flags: true
      },
      system: {
        user_management: true,
        role_management: true,
        permission_management: true,
        audit_logs: true,
        system_health: true,
        backup_restore: true
      }
    };

    return new AdminPermissions(
      superAdminData.venues,
      superAdminData.platform,
      superAdminData.system
    );
  }

  public static createPlatformAdminPermissions(): AdminPermissions {
    const platformAdminData: AdminPermissionsData = {
      venues: {
        create: true,
        read: true,
        update: true,
        delete: false,
        suspend: true,
        archive: false,
        billing: true
      },
      platform: {
        analytics: true,
        billing: true,
        system_config: false,
        emergency_access: false,
        maintenance_mode: false,
        feature_flags: false
      },
      system: {
        user_management: false,
        role_management: false,
        permission_management: false,
        audit_logs: true,
        system_health: true,
        backup_restore: false
      }
    };

    return new AdminPermissions(
      platformAdminData.venues,
      platformAdminData.platform,
      platformAdminData.system
    );
  }

  private static validate(data: AdminPermissionsData): Result<void, string> {
    // Validate venue permissions
    if (data.venues) {
      for (const [permission, value] of Object.entries(data.venues)) {
        if (typeof value !== 'boolean') {
          return Result.failure(`Venue permission '${permission}' must be a boolean`);
        }
      }
    }

    // Validate platform permissions
    if (data.platform) {
      for (const [permission, value] of Object.entries(data.platform)) {
        if (typeof value !== 'boolean') {
          return Result.failure(`Platform permission '${permission}' must be a boolean`);
        }
      }
    }

    // Validate system permissions
    if (data.system) {
      for (const [permission, value] of Object.entries(data.system)) {
        if (typeof value !== 'boolean') {
          return Result.failure(`System permission '${permission}' must be a boolean`);
        }
      }
    }

    return Result.success(undefined);
  }

  /**
   * Permission checking methods
   */
  public hasVenuePermission(permission: string): boolean {
    return this._venuePermissions[permission as keyof VenuePermissions] === true;
  }

  public hasPlatformPermission(permission: string): boolean {
    return this._platformPermissions[permission as keyof PlatformPermissions] === true;
  }

  public hasSystemPermission(permission: string): boolean {
    return this._systemPermissions[permission as keyof SystemPermissions] === true;
  }

  public hasPermission(category: 'venue' | 'platform' | 'system', permission: string): boolean {
    switch (category) {
      case 'venue':
        return this.hasVenuePermission(permission);
      case 'platform':
        return this.hasPlatformPermission(permission);
      case 'system':
        return this.hasSystemPermission(permission);
      default:
        return false;
    }
  }

  /**
   * Permission management
   */
  public grantVenuePermission(permission: string): AdminPermissions {
    const newVenuePermissions = {
      ...this._venuePermissions,
      [permission]: true
    };

    return new AdminPermissions(
      newVenuePermissions,
      this._platformPermissions,
      this._systemPermissions
    );
  }

  public revokeVenuePermission(permission: string): AdminPermissions {
    const newVenuePermissions = {
      ...this._venuePermissions,
      [permission]: false
    };

    return new AdminPermissions(
      newVenuePermissions,
      this._platformPermissions,
      this._systemPermissions
    );
  }

  public grantPlatformPermission(permission: string): AdminPermissions {
    const newPlatformPermissions = {
      ...this._platformPermissions,
      [permission]: true
    };

    return new AdminPermissions(
      this._venuePermissions,
      newPlatformPermissions,
      this._systemPermissions
    );
  }

  public revokePlatformPermission(permission: string): AdminPermissions {
    const newPlatformPermissions = {
      ...this._platformPermissions,
      [permission]: false
    };

    return new AdminPermissions(
      this._venuePermissions,
      newPlatformPermissions,
      this._systemPermissions
    );
  }

  public grantSystemPermission(permission: string): AdminPermissions {
    const newSystemPermissions = {
      ...this._systemPermissions,
      [permission]: true
    };

    return new AdminPermissions(
      this._venuePermissions,
      this._platformPermissions,
      newSystemPermissions
    );
  }

  public revokeSystemPermission(permission: string): AdminPermissions {
    const newSystemPermissions = {
      ...this._systemPermissions,
      [permission]: false
    };

    return new AdminPermissions(
      this._venuePermissions,
      this._platformPermissions,
      newSystemPermissions
    );
  }

  /**
   * Permission set operations
   */
  public merge(other: AdminPermissions): AdminPermissions {
    const mergedVenuePermissions = {
      ...this._venuePermissions,
      ...other._venuePermissions
    };

    const mergedPlatformPermissions = {
      ...this._platformPermissions,
      ...other._platformPermissions
    };

    const mergedSystemPermissions = {
      ...this._systemPermissions,
      ...other._systemPermissions
    };

    return new AdminPermissions(
      mergedVenuePermissions,
      mergedPlatformPermissions,
      mergedSystemPermissions
    );
  }

  public intersect(other: AdminPermissions): AdminPermissions {
    const intersectedVenuePermissions: VenuePermissions = {};
    for (const [key, value] of Object.entries(this._venuePermissions)) {
      if (value && other._venuePermissions[key as keyof VenuePermissions]) {
        intersectedVenuePermissions[key as keyof VenuePermissions] = true;
      }
    }

    const intersectedPlatformPermissions: PlatformPermissions = {};
    for (const [key, value] of Object.entries(this._platformPermissions)) {
      if (value && other._platformPermissions[key as keyof PlatformPermissions]) {
        intersectedPlatformPermissions[key as keyof PlatformPermissions] = true;
      }
    }

    const intersectedSystemPermissions: SystemPermissions = {};
    for (const [key, value] of Object.entries(this._systemPermissions)) {
      if (value && other._systemPermissions[key as keyof SystemPermissions]) {
        intersectedSystemPermissions[key as keyof SystemPermissions] = true;
      }
    }

    return new AdminPermissions(
      intersectedVenuePermissions,
      intersectedPlatformPermissions,
      intersectedSystemPermissions
    );
  }

  /**
   * Query methods
   */
  public getGrantedVenuePermissions(): string[] {
    return Object.entries(this._venuePermissions)
      .filter(([_, granted]) => granted === true)
      .map(([permission]) => permission);
  }

  public getGrantedPlatformPermissions(): string[] {
    return Object.entries(this._platformPermissions)
      .filter(([_, granted]) => granted === true)
      .map(([permission]) => permission);
  }

  public getGrantedSystemPermissions(): string[] {
    return Object.entries(this._systemPermissions)
      .filter(([_, granted]) => granted === true)
      .map(([permission]) => permission);
  }

  public getAllGrantedPermissions(): { category: string; permissions: string[] }[] {
    return [
      { category: 'venue', permissions: this.getGrantedVenuePermissions() },
      { category: 'platform', permissions: this.getGrantedPlatformPermissions() },
      { category: 'system', permissions: this.getGrantedSystemPermissions() }
    ];
  }

  public isEmpty(): boolean {
    return (
      this.getGrantedVenuePermissions().length === 0 &&
      this.getGrantedPlatformPermissions().length === 0 &&
      this.getGrantedSystemPermissions().length === 0
    );
  }

  public hasAnyVenuePermissions(): boolean {
    return this.getGrantedVenuePermissions().length > 0;
  }

  public hasAnyPlatformPermissions(): boolean {
    return this.getGrantedPlatformPermissions().length > 0;
  }

  public hasAnySystemPermissions(): boolean {
    return this.getGrantedSystemPermissions().length > 0;
  }

  /**
   * Getters
   */
  public get venuePermissions(): VenuePermissions {
    return { ...this._venuePermissions };
  }

  public get platformPermissions(): PlatformPermissions {
    return { ...this._platformPermissions };
  }

  public get systemPermissions(): SystemPermissions {
    return { ...this._systemPermissions };
  }

  /**
   * Serialization
   */
  public toJSON(): AdminPermissionsData {
    return {
      venues: this._venuePermissions,
      platform: this._platformPermissions,
      system: this._systemPermissions
    };
  }

  public equals(other: AdminPermissions): boolean {
    return JSON.stringify(this.toJSON()) === JSON.stringify(other.toJSON());
  }

  public toString(): string {
    const granted = this.getAllGrantedPermissions();
    return granted
      .map(({ category, permissions }) => 
        `${category}: [${permissions.join(', ')}]`
      )
      .join('; ');
  }
}

