import { Result } from '@thankful/result';

/**
 * Admin Role value object
 * Represents the role level for platform administrators
 */
export class AdminRole {
  public static readonly SUPER_ADMIN = new AdminRole('SuperAdmin');
  public static readonly PLATFORM_ADMIN = new AdminRole('PlatformAdmin');

  private constructor(private readonly _value: string) {}

  public static create(value: string): Result<AdminRole, string> {
    const normalizedValue = this.normalizeRole(value);
    
    if (!this.isValidRole(normalizedValue)) {
      return Result.failure(`Invalid admin role: ${value}`);
    }

    return Result.success(new AdminRole(normalizedValue));
  }

  public static fromString(value: string): AdminRole {
    const result = this.create(value);
    if (!result.success) {
      throw new Error(result.error);
    }
    return result.value;
  }

  private static normalizeRole(value: string): string {
    return value.trim()
      .split(/[\s_-]+/)
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join('');
  }

  private static isValidRole(value: string): boolean {
    return ['SuperAdmin', 'PlatformAdmin'].includes(value);
  }

  /**
   * Role hierarchy and permissions
   */
  public isSuperAdmin(): boolean {
    return this._value === 'SuperAdmin';
  }

  public isPlatformAdmin(): boolean {
    return this._value === 'PlatformAdmin';
  }

  public hasHigherOrEqualAuthority(other: AdminRole): boolean {
    if (this.isSuperAdmin()) {
      return true; // Super admin has highest authority
    }
    
    if (this.isPlatformAdmin()) {
      return other.isPlatformAdmin(); // Platform admin equal to platform admin only
    }
    
    return false;
  }

  public canManageRole(targetRole: AdminRole): boolean {
    if (this.isSuperAdmin()) {
      return true; // Super admin can manage all roles
    }
    
    if (this.isPlatformAdmin()) {
      return targetRole.isPlatformAdmin(); // Platform admin can only manage platform admins
    }
    
    return false;
  }

  /**
   * Default permissions for role
   */
  public getDefaultPermissions(): AdminPermissionsData {
    switch (this._value) {
      case 'SuperAdmin':
        return {
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

      case 'PlatformAdmin':
        return {
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

      default:
        return {
          venues: {},
          platform: {},
          system: {}
        };
    }
  }

  /**
   * Role validation rules
   */
  public getValidTransitions(): AdminRole[] {
    switch (this._value) {
      case 'SuperAdmin':
        return [AdminRole.PLATFORM_ADMIN]; // Super admin can be demoted to platform admin
      case 'PlatformAdmin':
        return [AdminRole.SUPER_ADMIN]; // Platform admin can be promoted to super admin
      default:
        return [];
    }
  }

  public canTransitionTo(targetRole: AdminRole): boolean {
    return this.getValidTransitions().some(role => role.equals(targetRole));
  }

  /**
   * Utility methods
   */
  public equals(other: AdminRole): boolean {
    return this._value === other._value;
  }

  public toString(): string {
    return this._value;
  }

  public get value(): string {
    return this._value;
  }

  /**
   * Static utility methods
   */
  public static getAllRoles(): AdminRole[] {
    return [AdminRole.SUPER_ADMIN, AdminRole.PLATFORM_ADMIN];
  }

  public static getRoleDescription(role: AdminRole): string {
    switch (role._value) {
      case 'SuperAdmin':
        return 'Full platform access with system administration capabilities';
      case 'PlatformAdmin':
        return 'Platform management access with venue administration capabilities';
      default:
        return 'Unknown role';
    }
  }

  public static getRolePriority(role: AdminRole): number {
    switch (role._value) {
      case 'SuperAdmin':
        return 100;
      case 'PlatformAdmin':
        return 50;
      default:
        return 0;
    }
  }

  public static compareRoles(role1: AdminRole, role2: AdminRole): number {
    return AdminRole.getRolePriority(role1) - AdminRole.getRolePriority(role2);
  }
}

/**
 * Supporting interfaces
 */
export interface AdminPermissionsData {
  venues: Record<string, boolean>;
  platform: Record<string, boolean>;
  system: Record<string, boolean>;
}

