import { Result } from '@thankful/result';

/**
 * Venue Configuration value object
 * Encapsulates all configuration settings for a venue
 */
export interface VenueConfigurationData {
  branding: VenueBranding;
  features: VenueFeatures;
  limits: VenueLimits;
  settings?: VenueSettings;
}

export interface VenueBranding {
  logoUrl?: string;
  primaryColor: string;
  secondaryColor: string;
  theme: VenueTheme;
  customCss?: string;
  faviconUrl?: string;
  customDomain?: string;
}

export interface VenueFeatures {
  ticketValidation: boolean;
  customerManagement: boolean;
  analytics: boolean;
  staffManagement: boolean;
  mobileApp: boolean;
  apiAccess: boolean;
  webhooks: boolean;
  customReports: boolean;
  multiLanguage: boolean;
  loyaltyProgram: boolean;
}

export interface VenueLimits {
  maxStaff: number;
  maxShowsPerMonth: number;
  maxCustomers: number;
  maxApiCallsPerMonth: number;
  maxStorageGb: number;
  maxConcurrentUsers: number;
}

export interface VenueSettings {
  timezone: string;
  defaultLanguage: string;
  currency: string;
  dateFormat: string;
  timeFormat: string;
  weekStartsOn: number; // 0 = Sunday, 1 = Monday
  notifications: VenueNotificationSettings;
  security: VenueSecuritySettings;
}

export interface VenueNotificationSettings {
  emailNotifications: boolean;
  smsNotifications: boolean;
  pushNotifications: boolean;
  webhookNotifications: boolean;
  notificationEmail: string;
  escalationEmail?: string;
}

export interface VenueSecuritySettings {
  requireTwoFactorAuth: boolean;
  sessionTimeoutMinutes: number;
  maxLoginAttempts: number;
  lockoutDurationMinutes: number;
  requirePasswordChange: boolean;
  passwordChangeIntervalDays: number;
  allowedIpAddresses?: string[];
}

export enum VenueTheme {
  DEFAULT = 'default',
  DARK = 'dark',
  LIGHT = 'light',
  CUSTOM = 'custom'
}

export class VenueConfiguration {
  private constructor(
    private readonly _data: VenueConfigurationData
  ) {}

  public static create(data: VenueConfigurationData): Result<VenueConfiguration, string> {
    const validation = VenueConfiguration.validate(data);
    if (!validation.success) {
      return validation;
    }

    return Result.success(new VenueConfiguration(data));
  }

  public static createDefault(): VenueConfiguration {
    const defaultData: VenueConfigurationData = {
      branding: {
        primaryColor: '#000000',
        secondaryColor: '#ffffff',
        theme: VenueTheme.DEFAULT
      },
      features: {
        ticketValidation: true,
        customerManagement: true,
        analytics: true,
        staffManagement: true,
        mobileApp: false,
        apiAccess: false,
        webhooks: false,
        customReports: false,
        multiLanguage: false,
        loyaltyProgram: false
      },
      limits: {
        maxStaff: 50,
        maxShowsPerMonth: 100,
        maxCustomers: 10000,
        maxApiCallsPerMonth: 100000,
        maxStorageGb: 10,
        maxConcurrentUsers: 100
      },
      settings: {
        timezone: 'UTC',
        defaultLanguage: 'en',
        currency: 'USD',
        dateFormat: 'YYYY-MM-DD',
        timeFormat: 'HH:mm',
        weekStartsOn: 1,
        notifications: {
          emailNotifications: true,
          smsNotifications: false,
          pushNotifications: true,
          webhookNotifications: false,
          notificationEmail: ''
        },
        security: {
          requireTwoFactorAuth: false,
          sessionTimeoutMinutes: 480,
          maxLoginAttempts: 5,
          lockoutDurationMinutes: 15,
          requirePasswordChange: false,
          passwordChangeIntervalDays: 90
        }
      }
    };

    return new VenueConfiguration(defaultData);
  }

  private static validate(data: VenueConfigurationData): Result<void, string> {
    // Validate branding
    if (!data.branding) {
      return Result.failure('Branding configuration is required');
    }

    if (!data.branding.primaryColor || !this.isValidColor(data.branding.primaryColor)) {
      return Result.failure('Valid primary color is required');
    }

    if (!data.branding.secondaryColor || !this.isValidColor(data.branding.secondaryColor)) {
      return Result.failure('Valid secondary color is required');
    }

    // Validate limits
    if (!data.limits) {
      return Result.failure('Limits configuration is required');
    }

    if (data.limits.maxStaff < 1) {
      return Result.failure('Max staff must be at least 1');
    }

    if (data.limits.maxShowsPerMonth < 1) {
      return Result.failure('Max shows per month must be at least 1');
    }

    if (data.limits.maxCustomers < 1) {
      return Result.failure('Max customers must be at least 1');
    }

    if (data.limits.maxStorageGb < 1) {
      return Result.failure('Max storage must be at least 1 GB');
    }

    // Validate settings if provided
    if (data.settings) {
      if (data.settings.notifications && !data.settings.notifications.notificationEmail) {
        return Result.failure('Notification email is required when notifications are enabled');
      }

      if (data.settings.security) {
        if (data.settings.security.sessionTimeoutMinutes < 5) {
          return Result.failure('Session timeout must be at least 5 minutes');
        }

        if (data.settings.security.maxLoginAttempts < 1) {
          return Result.failure('Max login attempts must be at least 1');
        }
      }
    }

    return Result.success(undefined);
  }

  private static isValidColor(color: string): boolean {
    // Simple hex color validation
    return /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(color);
  }

  /**
   * Update branding configuration
   */
  public updateBranding(branding: Partial<VenueBranding>): Result<VenueConfiguration, string> {
    const newBranding = { ...this._data.branding, ...branding };
    const newData = { ...this._data, branding: newBranding };
    
    return VenueConfiguration.create(newData);
  }

  /**
   * Update feature flags
   */
  public updateFeatures(features: Partial<VenueFeatures>): VenueConfiguration {
    const newFeatures = { ...this._data.features, ...features };
    const newData = { ...this._data, features: newFeatures };
    
    return new VenueConfiguration(newData);
  }

  /**
   * Update limits
   */
  public updateLimits(limits: Partial<VenueLimits>): Result<VenueConfiguration, string> {
    const newLimits = { ...this._data.limits, ...limits };
    const newData = { ...this._data, limits: newLimits };
    
    return VenueConfiguration.create(newData);
  }

  /**
   * Update settings
   */
  public updateSettings(settings: Partial<VenueSettings>): VenueConfiguration {
    const newSettings = { ...this._data.settings, ...settings };
    const newData = { ...this._data, settings: newSettings };
    
    return new VenueConfiguration(newData);
  }

  /**
   * Check if feature is enabled
   */
  public isFeatureEnabled(feature: keyof VenueFeatures): boolean {
    return this._data.features[feature];
  }

  /**
   * Check if limit is exceeded
   */
  public isLimitExceeded(limit: keyof VenueLimits, currentValue: number): boolean {
    return currentValue >= this._data.limits[limit];
  }

  /**
   * Get remaining capacity for a limit
   */
  public getRemainingCapacity(limit: keyof VenueLimits, currentValue: number): number {
    return Math.max(0, this._data.limits[limit] - currentValue);
  }

  /**
   * Getters
   */
  public get data(): VenueConfigurationData {
    return { ...this._data };
  }

  public get branding(): VenueBranding {
    return { ...this._data.branding };
  }

  public get features(): VenueFeatures {
    return { ...this._data.features };
  }

  public get limits(): VenueLimits {
    return { ...this._data.limits };
  }

  public get settings(): VenueSettings | undefined {
    return this._data.settings ? { ...this._data.settings } : undefined;
  }

  /**
   * Serialization
   */
  public toJSON(): VenueConfigurationData {
    return this._data;
  }
}

