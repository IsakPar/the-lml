import { Result } from '@thankful/shared';
import { MongoClient, Db, Collection } from 'mongodb';

/**
 * MongoDB repository for immutable venue seatmaps
 * Optimized for mobile app performance and versioning
 */
export class MongoSeatmapRepository {
  private db: Db;
  private seatmapsCollection: Collection;
  private versionsCollection: Collection;
  private snapshotsCollection: Collection;
  private cacheCollection: Collection;

  constructor(mongoClient: MongoClient, databaseName: string = 'thankful') {
    this.db = mongoClient.db(databaseName);
    this.seatmapsCollection = this.db.collection('seatmaps');
    this.versionsCollection = this.db.collection('seatmap_versions');
    this.snapshotsCollection = this.db.collection('seatmap_snapshots');
    this.cacheCollection = this.db.collection('seatmap_cache');
  }

  /**
   * Save a new seatmap version
   */
  async saveSeatmap(seatmap: VenueSeatmap): Promise<Result<VenueSeatmap, SeatmapError>> {
    try {
      // Calculate hash for integrity
      const hash = this.calculateSeatmapHash(seatmap);
      const seatmapWithHash = { ...seatmap, hash, created_at: new Date(), updated_at: new Date() };

      // Check if version already exists
      const existing = await this.seatmapsCollection.findOne({
        venue_id: seatmap.venue_id,
        version: seatmap.version
      });

      if (existing) {
        return Result.failure(SeatmapError.versionExists(
          `Seatmap version ${seatmap.version} already exists for venue ${seatmap.venue_id}`
        ));
      }

      // Insert new seatmap
      const result = await this.seatmapsCollection.insertOne(seatmapWithHash);
      
      if (!result.insertedId) {
        return Result.failure(SeatmapError.saveFailed('Failed to insert seatmap'));
      }

      // Create version history entry
      await this.createVersionHistory(seatmap);

      // Invalidate cache
      await this.invalidateCache(seatmap.venue_id);

      return Result.success({ ...seatmapWithHash, _id: result.insertedId });

    } catch (error: any) {
      console.error('Error saving seatmap:', error);
      return Result.failure(SeatmapError.saveFailed(`Failed to save seatmap: ${error.message}`));
    }
  }

  /**
   * Get latest published seatmap for a venue
   */
  async getLatestSeatmap(venueId: string): Promise<Result<VenueSeatmap | null, SeatmapError>> {
    try {
      const seatmap = await this.seatmapsCollection.findOne(
        {
          venue_id: venueId,
          is_published: true
        },
        {
          sort: { published_at: -1 }
        }
      );

      if (!seatmap) {
        return Result.success(null);
      }

      // Verify integrity
      if (!this.verifySeatmapIntegrity(seatmap)) {
        return Result.failure(SeatmapError.corruptedData('Seatmap data integrity check failed'));
      }

      return Result.success(seatmap as VenueSeatmap);

    } catch (error: any) {
      console.error('Error getting latest seatmap:', error);
      return Result.failure(SeatmapError.queryFailed(`Failed to get seatmap: ${error.message}`));
    }
  }

  /**
   * Get specific seatmap version
   */
  async getSeatmapVersion(venueId: string, version: string): Promise<Result<VenueSeatmap | null, SeatmapError>> {
    try {
      const seatmap = await this.seatmapsCollection.findOne({
        venue_id: venueId,
        version: version
      });

      if (!seatmap) {
        return Result.success(null);
      }

      // Verify integrity
      if (!this.verifySeatmapIntegrity(seatmap)) {
        return Result.failure(SeatmapError.corruptedData('Seatmap data integrity check failed'));
      }

      return Result.success(seatmap as VenueSeatmap);

    } catch (error: any) {
      console.error('Error getting seatmap version:', error);
      return Result.failure(SeatmapError.queryFailed(`Failed to get seatmap: ${error.message}`));
    }
  }

  /**
   * Create event-specific seatmap snapshot
   */
  async createEventSnapshot(eventId: string, venueId: string, customizations?: EventCustomizations): Promise<Result<EventSeatmapSnapshot, SeatmapError>> {
    try {
      // Get latest seatmap
      const seatmapResult = await this.getLatestSeatmap(venueId);
      if (seatmapResult.isFailure) {
        return Result.failure(seatmapResult.error);
      }

      const baseSeatmap = seatmapResult.value;
      if (!baseSeatmap) {
        return Result.failure(SeatmapError.notFound(`No seatmap found for venue ${venueId}`));
      }

      // Apply event customizations
      const eventSeatmap = this.applyEventCustomizations(baseSeatmap, customizations);

      // Create snapshot
      const snapshot: EventSeatmapSnapshot = {
        _id: undefined,
        event_id: eventId,
        venue_id: venueId,
        seatmap_version: baseSeatmap.version,
        event_customizations: customizations || {},
        initial_availability: this.calculateInitialAvailability(eventSeatmap),
        created_at: new Date(),
        frozen_at: new Date(),
        hash: this.calculateSeatmapHash(eventSeatmap)
      };

      const result = await this.snapshotsCollection.insertOne(snapshot);
      
      if (!result.insertedId) {
        return Result.failure(SeatmapError.saveFailed('Failed to create event snapshot'));
      }

      return Result.success({ ...snapshot, _id: result.insertedId });

    } catch (error: any) {
      console.error('Error creating event snapshot:', error);
      return Result.failure(SeatmapError.saveFailed(`Failed to create snapshot: ${error.message}`));
    }
  }

  /**
   * Get mobile-optimized seatmap data
   */
  async getMobileSeatmap(venueId: string, zoomLevel: number = 1): Promise<Result<MobileSeatmapData, SeatmapError>> {
    try {
      // Check cache first
      const cacheKey = `${venueId}:zoom:${zoomLevel}`;
      const cached = await this.cacheCollection.findOne({ cache_key: cacheKey });

      if (cached && !this.isCacheExpired(cached)) {
        return Result.success(cached.optimized_data as MobileSeatmapData);
      }

      // Get full seatmap
      const seatmapResult = await this.getLatestSeatmap(venueId);
      if (seatmapResult.isFailure) {
        return Result.failure(seatmapResult.error);
      }

      const seatmap = seatmapResult.value;
      if (!seatmap) {
        return Result.failure(SeatmapError.notFound(`No seatmap found for venue ${venueId}`));
      }

      // Optimize for mobile
      const optimizedData = this.optimizeForMobile(seatmap, zoomLevel);

      // Cache the result
      await this.cacheCollection.replaceOne(
        { cache_key: cacheKey },
        {
          cache_key: cacheKey,
          venue_id: venueId,
          zoom_level: zoomLevel,
          optimized_data: optimizedData,
          created_at: new Date(),
          expires_at: new Date(Date.now() + 3600000) // 1 hour
        },
        { upsert: true }
      );

      return Result.success(optimizedData);

    } catch (error: any) {
      console.error('Error getting mobile seatmap:', error);
      return Result.failure(SeatmapError.queryFailed(`Failed to get mobile seatmap: ${error.message}`));
    }
  }

  /**
   * Get seatmap statistics
   */
  async getSeatmapStats(venueId?: string): Promise<Result<SeatmapStats[], SeatmapError>> {
    try {
      const matchStage = venueId ? { venue_id: venueId } : {};

      const stats = await this.seatmapsCollection.aggregate([
        { $match: matchStage },
        {
          $group: {
            _id: '$venue_id',
            total_versions: { $sum: 1 },
            latest_version: { $max: '$version' },
            total_capacity: { $last: '$total_capacity' },
            last_updated: { $max: '$updated_at' },
            published_versions: {
              $sum: { $cond: ['$is_published', 1, 0] }
            }
          }
        },
        { $sort: { total_capacity: -1 } }
      ]).toArray();

      return Result.success(stats.map(stat => ({
        venue_id: stat._id,
        total_versions: stat.total_versions,
        latest_version: stat.latest_version,
        total_capacity: stat.total_capacity,
        last_updated: stat.last_updated,
        published_versions: stat.published_versions
      })));

    } catch (error: any) {
      console.error('Error getting seatmap stats:', error);
      return Result.failure(SeatmapError.queryFailed(`Failed to get stats: ${error.message}`));
    }
  }

  /**
   * Publish a seatmap version
   */
  async publishSeatmap(venueId: string, version: string): Promise<Result<void, SeatmapError>> {
    try {
      // Unpublish current published version
      await this.seatmapsCollection.updateMany(
        { venue_id: venueId, is_published: true },
        { $set: { is_published: false } }
      );

      // Publish the specified version
      const result = await this.seatmapsCollection.updateOne(
        { venue_id: venueId, version: version },
        { 
          $set: { 
            is_published: true, 
            published_at: new Date(),
            updated_at: new Date()
          } 
        }
      );

      if (result.matchedCount === 0) {
        return Result.failure(SeatmapError.notFound(`Seatmap version ${version} not found`));
      }

      // Invalidate cache
      await this.invalidateCache(venueId);

      return Result.success(undefined);

    } catch (error: any) {
      console.error('Error publishing seatmap:', error);
      return Result.failure(SeatmapError.saveFailed(`Failed to publish seatmap: ${error.message}`));
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /**
   * Calculate hash for seatmap integrity
   */
  private calculateSeatmapHash(seatmap: any): string {
    const crypto = require('crypto');
    const content = JSON.stringify({
      venue_id: seatmap.venue_id,
      version: seatmap.version,
      sections: seatmap.sections,
      venue_dimensions: seatmap.venue_dimensions
    });
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  /**
   * Verify seatmap data integrity
   */
  private verifySeatmapIntegrity(seatmap: any): boolean {
    if (!seatmap.hash) {
      return false; // Legacy data without hash
    }

    const calculatedHash = this.calculateSeatmapHash(seatmap);
    return calculatedHash === seatmap.hash;
  }

  /**
   * Create version history entry
   */
  private async createVersionHistory(seatmap: VenueSeatmap): Promise<void> {
    const versionEntry = {
      venue_id: seatmap.venue_id,
      version: seatmap.version,
      previous_version: null, // Would be calculated
      change_type: 'new_layout',
      change_summary: 'New seatmap version created',
      created_by: 'system', // Would come from context
      created_at: new Date(),
      requires_approval: false,
      can_rollback: true
    };

    await this.versionsCollection.insertOne(versionEntry);
  }

  /**
   * Apply event-specific customizations
   */
  private applyEventCustomizations(baseSeatmap: VenueSeatmap, customizations?: EventCustomizations): VenueSeatmap {
    if (!customizations) {
      return baseSeatmap;
    }

    const customizedSeatmap = { ...baseSeatmap };

    // Apply blocked sections
    if (customizations.blocked_sections) {
      customizedSeatmap.sections = customizedSeatmap.sections.filter(
        section => !customizations.blocked_sections?.includes(section.id)
      );
    }

    // Add temporary sections
    if (customizations.added_sections) {
      customizedSeatmap.sections.push(...customizations.added_sections);
    }

    return customizedSeatmap;
  }

  /**
   * Calculate initial seat availability
   */
  private calculateInitialAvailability(seatmap: VenueSeatmap): any {
    const availability = {
      total_seats: 0,
      available_seats: 0,
      blocked_seats: 0,
      by_section: {} as Record<string, any>
    };

    seatmap.sections.forEach(section => {
      const sectionAvailability = {
        total: section.capacity,
        available: section.capacity,
        blocked: 0
      };

      availability.total_seats += section.capacity;
      availability.available_seats += section.capacity;
      availability.by_section[section.id] = sectionAvailability;
    });

    return availability;
  }

  /**
   * Optimize seatmap for mobile rendering
   */
  private optimizeForMobile(seatmap: VenueSeatmap, zoomLevel: number): MobileSeatmapData {
    const optimizations = seatmap.mobile_optimizations?.zoom_levels?.find(
      level => level.level === zoomLevel
    );

    return {
      venue_id: seatmap.venue_id,
      version: seatmap.version,
      venue_dimensions: seatmap.venue_dimensions,
      stage: seatmap.stage,
      sections: seatmap.sections.map(section => ({
        id: section.id,
        name: section.name,
        type: section.type,
        position: section.position,
        display: section.display,
        capacity: section.capacity,
        seat_count: section.seats?.length || 0,
        // Include seat details only for high zoom levels
        seats: optimizations?.show_seat_numbers ? section.seats : undefined
      })),
      amenities: optimizations?.show_amenities ? (seatmap.amenities || []) : [],
      zoom_level: zoomLevel,
      optimized_for_mobile: true
    };
  }

  /**
   * Check if cache entry is expired
   */
  private isCacheExpired(cacheEntry: any): boolean {
    return new Date() > new Date(cacheEntry.expires_at);
  }

  /**
   * Invalidate cache for venue
   */
  private async invalidateCache(venueId: string): Promise<void> {
    await this.cacheCollection.deleteMany({ venue_id: venueId });
  }
}

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

export interface VenueSeatmap {
  _id?: any;
  venue_id: string;
  version: string;
  name: string;
  description?: string;
  total_capacity: number;
  venue_dimensions: {
    width: number;
    height: number;
    units: string;
    scale_factor: number;
  };
  stage?: {
    x: number;
    y: number;
    width: number;
    height: number;
    rotation: number;
    label: string;
  };
  sections: VenueSection[];
  amenities?: Amenity[];
  emergency_exits?: EmergencyExit[];
  mobile_optimizations?: MobileOptimizations;
  is_published: boolean;
  created_at: Date;
  updated_at: Date;
  published_at?: Date;
  hash?: string;
}

export interface VenueSection {
  id: string;
  name: string;
  type: string;
  position: {
    x: number;
    y: number;
    width: number;
    height: number;
    rotation: number;
  };
  display: {
    color: string;
    text_color: string;
    border_color: string;
    opacity: number;
    display_order: number;
  };
  capacity: number;
  characteristics: string[];
  accessibility_features?: string[];
  seats?: Seat[];
}

export interface Seat {
  id: string;
  row: string;
  number: number;
  coordinates: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  type: string;
  is_accessible: boolean;
  is_companion_seat: boolean;
  is_obstructed_view: boolean;
  sight_line_rating: number;
  distance_to_stage_meters: number;
  viewing_angle_degrees: number;
  suggested_price_tier: string;
}

export interface Amenity {
  type: string;
  name: string;
  coordinates: { x: number; y: number };
  is_accessible: boolean;
  icon: string;
}

export interface EmergencyExit {
  name: string;
  coordinates: { x: number; y: number };
  width: number;
  capacity_per_minute: number;
}

export interface MobileOptimizations {
  zoom_levels: Array<{
    level: number;
    min_zoom: number;
    max_zoom: number;
    show_seat_numbers: boolean;
    show_amenities: boolean;
  }>;
  section_groups: Array<{
    name: string;
    sections: string[];
    priority: number;
  }>;
}

export interface EventCustomizations {
  stage_setup?: string;
  blocked_sections?: string[];
  added_sections?: VenueSection[];
  pricing_zones?: Array<{
    sections: string[];
    zone_name: string;
    base_price: number;
  }>;
}

export interface EventSeatmapSnapshot {
  _id?: any;
  event_id: string;
  venue_id: string;
  seatmap_version: string;
  event_customizations: EventCustomizations;
  initial_availability: any;
  created_at: Date;
  frozen_at: Date;
  hash: string;
}

export interface MobileSeatmapData {
  venue_id: string;
  version: string;
  venue_dimensions: any;
  stage?: any;
  sections: Array<{
    id: string;
    name: string;
    type: string;
    position: any;
    display: any;
    capacity: number;
    seat_count: number;
    seats?: Seat[];
  }>;
  amenities: Amenity[];
  zoom_level: number;
  optimized_for_mobile: boolean;
}

export interface SeatmapStats {
  venue_id: string;
  total_versions: number;
  latest_version: string;
  total_capacity: number;
  last_updated: Date;
  published_versions: number;
}

/**
 * Seatmap error types
 */
export interface SeatmapError {
  type: 'VERSION_EXISTS' | 'NOT_FOUND' | 'CORRUPTED_DATA' | 'SAVE_FAILED' | 'QUERY_FAILED';
  message: string;
  details?: Record<string, any>;
}

export const SeatmapError = {
  versionExists: (message: string): SeatmapError => ({
    type: 'VERSION_EXISTS',
    message,
  }),

  notFound: (message: string): SeatmapError => ({
    type: 'NOT_FOUND',
    message,
  }),

  corruptedData: (message: string): SeatmapError => ({
    type: 'CORRUPTED_DATA',
    message,
  }),

  saveFailed: (message: string): SeatmapError => ({
    type: 'SAVE_FAILED',
    message,
  }),

  queryFailed: (message: string): SeatmapError => ({
    type: 'QUERY_FAILED',
    message,
  }),
};
