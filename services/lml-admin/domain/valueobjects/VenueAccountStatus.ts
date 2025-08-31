/**
 * Venue Account Status value object
 * Represents the current status of a venue account on the platform
 */
export enum VenueAccountStatus {
  PENDING = 'pending',
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  ARCHIVED = 'archived'
}

export class VenueAccountStatusError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'VenueAccountStatusError';
  }
}

/**
 * Validate venue account status transitions
 */
export class VenueAccountStatusTransition {
  private static readonly VALID_TRANSITIONS = new Map([
    [VenueAccountStatus.PENDING, [VenueAccountStatus.ACTIVE, VenueAccountStatus.ARCHIVED]],
    [VenueAccountStatus.ACTIVE, [VenueAccountStatus.SUSPENDED, VenueAccountStatus.ARCHIVED]],
    [VenueAccountStatus.SUSPENDED, [VenueAccountStatus.ACTIVE, VenueAccountStatus.ARCHIVED]],
    [VenueAccountStatus.ARCHIVED, []] // Terminal state
  ]);

  public static isValidTransition(
    fromStatus: VenueAccountStatus,
    toStatus: VenueAccountStatus
  ): boolean {
    const allowedTransitions = this.VALID_TRANSITIONS.get(fromStatus);
    return allowedTransitions ? allowedTransitions.includes(toStatus) : false;
  }

  public static getValidTransitions(fromStatus: VenueAccountStatus): VenueAccountStatus[] {
    return this.VALID_TRANSITIONS.get(fromStatus) || [];
  }

  public static validateTransition(
    fromStatus: VenueAccountStatus,
    toStatus: VenueAccountStatus
  ): void {
    if (!this.isValidTransition(fromStatus, toStatus)) {
      throw new VenueAccountStatusError(
        `Invalid status transition from ${fromStatus} to ${toStatus}`
      );
    }
  }
}

/**
 * Utility functions for venue account status
 */
export class VenueAccountStatusUtils {
  public static isOperational(status: VenueAccountStatus): boolean {
    return status === VenueAccountStatus.ACTIVE;
  }

  public static isAccessible(status: VenueAccountStatus): boolean {
    return status === VenueAccountStatus.ACTIVE || status === VenueAccountStatus.SUSPENDED;
  }

  public static canBeActivated(status: VenueAccountStatus): boolean {
    return status === VenueAccountStatus.PENDING || status === VenueAccountStatus.SUSPENDED;
  }

  public static canBeSuspended(status: VenueAccountStatus): boolean {
    return status === VenueAccountStatus.ACTIVE;
  }

  public static canBeArchived(status: VenueAccountStatus): boolean {
    return status !== VenueAccountStatus.ARCHIVED;
  }

  public static fromString(statusString: string): VenueAccountStatus {
    const status = Object.values(VenueAccountStatus).find(
      s => s === statusString.toLowerCase()
    );
    
    if (!status) {
      throw new VenueAccountStatusError(`Invalid venue account status: ${statusString}`);
    }
    
    return status;
  }

  public static toString(status: VenueAccountStatus): string {
    return status;
  }

  public static getAllStatuses(): VenueAccountStatus[] {
    return Object.values(VenueAccountStatus);
  }

  public static getStatusDescription(status: VenueAccountStatus): string {
    switch (status) {
      case VenueAccountStatus.PENDING:
        return 'Account created but not yet activated';
      case VenueAccountStatus.ACTIVE:
        return 'Account is active and operational';
      case VenueAccountStatus.SUSPENDED:
        return 'Account is temporarily suspended';
      case VenueAccountStatus.ARCHIVED:
        return 'Account is permanently archived';
      default:
        return 'Unknown status';
    }
  }
}

