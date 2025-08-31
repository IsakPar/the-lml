import { VenuePermissions, VenueIsolationConfig } from './types.js';
import { VenueIsolationService } from './VenueIsolationService.js';
import { VenueIsolationMiddleware } from './VenueIsolationMiddleware.js';
import { Logger } from '@thankful/logging';

/**
 * Create default venue permissions with conservative access levels
 */
export function createDefaultVenuePermissions(): VenuePermissions {
  return {
    customers: {
      read: true,
      create: false,
      update: false,
      delete: false,
      export: false
    },
    shows: {
      read: true,
      create: false,
      update: false,
      delete: false
    },
    tickets: {
      read: true,
      create: false,
      update: false,
      delete: false,
      validate: false,
      refund: false
    },
    analytics: {
      read: false,
      create: false,
      update: false,
      delete: false,
      export: false
    },
    staff: {
      read: false,
      create: false,
      update: false,
      delete: false,
      manage: false
    },
    venue: {
      read: false,
      create: false,
      update: false,
      delete: false,
      manage: false
    }
  };
}

/**
 * Create venue admin permissions with full access
 */
export function createVenueAdminPermissions(): VenuePermissions {
  return {
    customers: {
      read: true,
      create: true,
      update: true,
      delete: true,
      export: true
    },
    shows: {
      read: true,
      create: true,
      update: true,
      delete: true
    },
    tickets: {
      read: true,
      create: true,
      update: true,
      delete: true,
      validate: true,
      refund: true
    },
    analytics: {
      read: true,
      create: true,
      update: true,
      delete: true,
      export: true
    },
    staff: {
      read: true,
      create: true,
      update: true,
      delete: true,
      manage: true
    },
    venue: {
      read: true,
      create: true,
      update: true,
      delete: true,
      manage: true
    }
  };
}

/**
 * Create venue staff permissions for ticket validation
 */
export function createVenueStaffPermissions(): VenuePermissions {
  return {
    customers: {
      read: true,
      create: false,
      update: false,
      delete: false,
      export: false
    },
    shows: {
      read: true,
      create: false,
      update: false,
      delete: false
    },
    tickets: {
      read: true,
      create: false,
      update: false,
      delete: false,
      validate: true,
      refund: false
    },
    analytics: {
      read: true,
      create: false,
      update: false,
      delete: false,
      export: false
    },
    staff: {
      read: false,
      create: false,
      update: false,
      delete: false,
      manage: false
    },
    venue: {
      read: false,
      create: false,
      update: false,
      delete: false,
      manage: false
    }
  };
}

/**
 * Create default venue isolation configuration
 */
export function createVenueIsolationConfig(overrides: Partial<VenueIsolationConfig> = {}): VenueIsolationConfig {
  return {
    enableStrictIsolation: true,
    logBoundaryViolations: true,
    blockCrossVenueAccess: true,
    auditAllAccess: false,
    defaultPermissions: createDefaultVenuePermissions(),
    tokenExpiryHours: 24,
    maxTokenRefreshes: 5,
    ...overrides
  };
}

/**
 * Create a complete venue isolation middleware stack
 */
export function createVenueMiddlewareStack(
  config: VenueIsolationConfig,
  logger?: Logger
) {
  const venueIsolationService = new VenueIsolationService(config, logger);
  const venueMiddleware = new VenueIsolationMiddleware(venueIsolationService, logger);
  
  return {
    service: venueIsolationService,
    middleware: venueMiddleware,
    stack: venueMiddleware.createVenueMiddlewareStack()
  };
}

/**
 * Merge venue permissions (used for role inheritance)
 */
export function mergeVenuePermissions(
  base: VenuePermissions,
  override: Partial<VenuePermissions>
): VenuePermissions {
  const merged: VenuePermissions = { ...base };
  
  for (const [resource, permissions] of Object.entries(override)) {
    if (merged[resource as keyof VenuePermissions]) {
      merged[resource as keyof VenuePermissions] = {
        ...merged[resource as keyof VenuePermissions],
        ...permissions
      };
    }
  }
  
  return merged;
}

/**
 * Check if permissions allow a specific action
 */
export function hasPermission(
  permissions: VenuePermissions,
  resource: keyof VenuePermissions,
  action: string
): boolean {
  const resourcePermissions = permissions[resource];
  if (!resourcePermissions) {
    return false;
  }
  
  return resourcePermissions[action as keyof typeof resourcePermissions] === true;
}

/**
 * Get all permitted actions for a resource
 */
export function getPermittedActions(
  permissions: VenuePermissions,
  resource: keyof VenuePermissions
): string[] {
  const resourcePermissions = permissions[resource];
  if (!resourcePermissions) {
    return [];
  }
  
  return Object.entries(resourcePermissions)
    .filter(([_, allowed]) => allowed === true)
    .map(([action]) => action);
}

/**
 * Create role-based permissions
 */
export function createRolePermissions(role: string): VenuePermissions {
  switch (role.toLowerCase()) {
    case 'venueadmin':
      return createVenueAdminPermissions();
    case 'venuestaff':
    case 'venuevalidator':
      return createVenueStaffPermissions();
    case 'boxoffice':
      return mergeVenuePermissions(createVenueStaffPermissions(), {
        customers: {
          read: true,
          create: true,
          update: true,
          export: true
        },
        tickets: {
          validate: true,
          refund: true
        }
      });
    case 'security':
      return mergeVenuePermissions(createDefaultVenuePermissions(), {
        tickets: {
          validate: true
        }
      });
    default:
      return createDefaultVenuePermissions();
  }
}

