/**
 * MongoDB Collections for LastMinuteLive
 * Handles immutable seatmap storage with versioning
 */

// ============================================================================
// VENUE SEATMAPS COLLECTION
// ============================================================================

/**
 * venues.seatmaps - Immutable venue layout storage
 * 
 * This collection stores complete venue layouts with full seat positioning
 * data for mobile app rendering. Each document is immutable and versioned.
 */
db.seatmaps.createIndex({ "venue_id": 1, "version": 1 }, { unique: true });
db.seatmaps.createIndex({ "venue_id": 1, "published_at": -1 });
db.seatmaps.createIndex({ "venue_id": 1, "is_published": 1 });
db.seatmaps.createIndex({ "created_at": -1 });
db.seatmaps.createIndex({ "hash": 1 }, { unique: true });

/**
 * Example seatmap document structure:
 */
const seatmapExample = {
  _id: ObjectId("507f1f77bcf86cd799439011"),
  venue_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  version: "v2.1",
  
  // Metadata
  name: "Madison Square Garden - Main Configuration",
  description: "Standard basketball/concert setup",
  total_capacity: 20789,
  
  // Publishing status
  is_published: true,
  published_at: ISODate("2025-01-09T14:30:00Z"),
  created_by: "staff_user_id",
  
  // Venue dimensions for mobile rendering
  venue_dimensions: {
    width: 1200,
    height: 800,
    units: "pixels", // or "meters"
    scale_factor: 2.5 // pixels per meter
  },
  
  // Stage/focal point positioning
  stage: {
    x: 600,
    y: 100,
    width: 200,
    height: 80,
    rotation: 0,
    label: "Main Stage"
  },
  
  // Complete sections array
  sections: [
    {
      id: "section_100",
      name: "Section 100",
      type: "standard", // standard, premium, vip, accessible, standing
      
      // Visual positioning
      position: {
        x: 400,
        y: 200,
        width: 200,
        height: 150,
        rotation: 0
      },
      
      // Styling for mobile apps
      display: {
        color: "#3498db",
        text_color: "#ffffff",
        border_color: "#2980b9",
        opacity: 1.0,
        display_order: 1
      },
      
      // Section metadata
      capacity: 200,
      row_count: 10,
      characteristics: ["numbered_seats", "back_support"],
      accessibility_features: ["wheelchair_accessible"],
      
      // Complete seats array with precise coordinates
      seats: [
        {
          id: "seat_100_A_1",
          row: "A",
          number: 1,
          
          // Precise positioning relative to section
          coordinates: {
            x: 10,
            y: 5,
            width: 18,
            height: 20
          },
          
          // Seat characteristics
          type: "standard",
          is_accessible: false,
          is_companion_seat: false,
          is_obstructed_view: false,
          
          // Viewing quality metrics
          sight_line_rating: 8, // 1-10 scale
          distance_to_stage_meters: 45.2,
          viewing_angle_degrees: 15,
          
          // Pricing hints (actual pricing in PostgreSQL)
          suggested_price_tier: "standard"
        },
        // ... more seats
      ]
    },
    
    {
      id: "section_vip_1",
      name: "VIP Box 1",
      type: "vip",
      
      position: {
        x: 100,
        y: 50,
        width: 120,
        height: 80,
        rotation: 0
      },
      
      display: {
        color: "#f39c12",
        text_color: "#ffffff", 
        border_color: "#e67e22",
        opacity: 1.0,
        display_order: 99 // Show on top
      },
      
      capacity: 20,
      row_count: 2,
      characteristics: ["premium_seats", "table_service", "private_entrance"],
      
      seats: [
        {
          id: "seat_vip_1_1_1",
          row: "1",
          number: 1,
          coordinates: { x: 5, y: 5, width: 25, height: 30 },
          type: "premium",
          sight_line_rating: 10,
          distance_to_stage_meters: 25.0,
          viewing_angle_degrees: 0,
          suggested_price_tier: "vip"
        }
        // ... more VIP seats
      ]
    }
  ],
  
  // Venue amenities positioning
  amenities: [
    {
      type: "restroom",
      name: "Women's Restroom - North",
      coordinates: { x: 1100, y: 300 },
      is_accessible: true,
      icon: "restroom_women"
    },
    {
      type: "concession",
      name: "Main Concession Stand",
      coordinates: { x: 600, y: 700 },
      is_accessible: true,
      icon: "food_drink"
    }
  ],
  
  // Emergency information
  emergency_exits: [
    {
      name: "Exit A",
      coordinates: { x: 50, y: 400 },
      width: 40,
      capacity_per_minute: 500
    }
  ],
  
  // Mobile app optimization
  mobile_optimizations: {
    zoom_levels: [
      {
        level: 1,
        min_zoom: 0.5,
        max_zoom: 1.0,
        show_seat_numbers: false,
        show_amenities: true
      },
      {
        level: 2, 
        min_zoom: 1.0,
        max_zoom: 3.0,
        show_seat_numbers: true,
        show_amenities: true
      }
    ],
    
    // Progressive loading for large venues
    section_groups: [
      {
        name: "Lower Bowl",
        sections: ["section_100", "section_101", "section_102"],
        priority: 1 // Load first
      },
      {
        name: "Upper Bowl", 
        sections: ["section_300", "section_301"],
        priority: 2
      }
    ]
  },
  
  // Data integrity
  hash: "sha256_of_complete_layout_data",
  checksum: "md5_for_quick_validation",
  
  // Audit trail
  created_at: ISODate("2025-01-09T14:30:00Z"),
  updated_at: ISODate("2025-01-09T14:30:00Z"),
  
  // Approval workflow
  approval_status: "approved", // draft, pending_approval, approved, rejected
  approved_by: "admin_user_id",
  approved_at: ISODate("2025-01-09T15:00:00Z"),
  
  // Usage statistics
  stats: {
    events_using_layout: 15,
    total_tickets_sold: 45230,
    last_used_at: ISODate("2025-01-08T20:00:00Z")
  }
};

// ============================================================================
// SEATMAP VERSIONS COLLECTION  
// ============================================================================

/**
 * venues.seatmap_versions - Version history and change tracking
 */
db.seatmap_versions.createIndex({ "venue_id": 1, "created_at": -1 });
db.seatmap_versions.createIndex({ "created_by": 1 });
db.seatmap_versions.createIndex({ "change_type": 1 });

const seatmapVersionExample = {
  _id: ObjectId("507f1f77bcf86cd799439012"),
  venue_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  version: "v2.1",
  previous_version: "v2.0",
  
  // Change information
  change_type: "section_modification", // new_layout, section_addition, section_modification, seat_adjustment
  change_summary: "Updated VIP section seating arrangement",
  change_details: {
    sections_added: [],
    sections_removed: [],
    sections_modified: ["section_vip_1"],
    seats_added: 0,
    seats_removed: 2,
    seats_modified: 5
  },
  
  // Change metadata
  created_by: "staff_user_id",
  created_at: ISODate("2025-01-09T14:30:00Z"),
  reason: "Customer feedback on VIP sight lines",
  
  // Approval information
  requires_approval: true,
  approved_by: "admin_user_id",
  approved_at: ISODate("2025-01-09T15:00:00Z"),
  
  // Migration info for active events
  migration_strategy: "immediate", // immediate, scheduled, manual
  affected_events: ["event_id_1", "event_id_2"],
  
  // Rollback capability
  can_rollback: true,
  rollback_safe: true
};

// ============================================================================
// EVENT SEATMAP SNAPSHOTS COLLECTION
// ============================================================================

/**
 * events.seatmap_snapshots - Point-in-time seatmap data for specific events
 * Immutable snapshot of seatmap when event goes on sale
 */
db.seatmap_snapshots.createIndex({ "event_id": 1 }, { unique: true });
db.seatmap_snapshots.createIndex({ "venue_id": 1, "created_at": -1 });
db.seatmap_snapshots.createIndex({ "seatmap_version": 1 });

const snapshotExample = {
  _id: ObjectId("507f1f77bcf86cd799439013"),
  event_id: "event_123",
  venue_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  seatmap_version: "v2.1",
  
  // Event-specific customizations
  event_customizations: {
    stage_setup: "concert_configuration",
    blocked_sections: ["section_behind_stage"],
    added_sections: [
      {
        id: "pit_standing",
        name: "General Admission Pit",
        type: "standing",
        capacity: 500,
        position: { x: 550, y: 150, width: 100, height: 100 }
      }
    ],
    
    // Event-specific pricing zones
    pricing_zones: [
      {
        sections: ["section_100", "section_101"],
        zone_name: "Premium",
        base_price: 15000 // cents
      },
      {
        sections: ["section_300", "section_301"], 
        zone_name: "Standard",
        base_price: 8000
      }
    ]
  },
  
  // Complete seat availability at event creation
  initial_availability: {
    total_seats: 19289, // Excluding blocked sections
    available_seats: 19289,
    blocked_seats: 1500,
    by_section: {
      "section_100": { total: 200, available: 200, blocked: 0 },
      "section_101": { total: 200, available: 200, blocked: 0 }
    }
  },
  
  // Immutable data
  created_at: ISODate("2024-12-01T10:00:00Z"),
  frozen_at: ISODate("2024-12-15T09:00:00Z"), // When event went on sale
  hash: "sha256_of_complete_event_seatmap"
};

// ============================================================================
// MOBILE APP CACHE COLLECTION
// ============================================================================

/**
 * mobile.seatmap_cache - Optimized seatmap data for mobile apps
 * Pre-computed and compressed seatmap data for different zoom levels
 */
db.seatmap_cache.createIndex({ "venue_id": 1, "zoom_level": 1, "version": 1 });
db.seatmap_cache.createIndex({ "created_at": -1 });
db.seatmap_cache.createIndex({ "cache_type": 1 });

const mobileCacheExample = {
  _id: ObjectId("507f1f77bcf86cd799439014"),
  venue_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  version: "v2.1",
  zoom_level: 1,
  cache_type: "section_overview", // section_overview, detailed_seats, amenities_only
  
  // Optimized data for mobile rendering
  optimized_data: {
    // Simplified section shapes for overview
    sections: [
      {
        id: "section_100",
        name: "100",
        path: "M400,200 L600,200 L600,350 L400,350 Z", // SVG path for section outline
        color: "#3498db",
        capacity: 200,
        center: { x: 500, y: 275 }
      }
    ],
    
    // Key landmarks
    landmarks: [
      { type: "stage", coordinates: { x: 600, y: 100 } },
      { type: "entrance", coordinates: { x: 600, y: 750 } }
    ]
  },
  
  // Compression info
  compression: {
    algorithm: "gzip",
    original_size_bytes: 45000,
    compressed_size_bytes: 8500,
    compression_ratio: 0.19
  },
  
  // Cache metadata
  created_at: ISODate("2025-01-09T14:30:00Z"),
  expires_at: ISODate("2025-01-16T14:30:00Z"),
  hit_count: 15420,
  last_accessed: ISODate("2025-01-09T16:45:00Z")
};

// ============================================================================
// VALIDATION SCHEMAS
// ============================================================================

/**
 * MongoDB Validation Schema for seatmaps collection
 */
db.createCollection("seatmaps", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["venue_id", "version", "name", "total_capacity", "sections", "hash"],
      properties: {
        venue_id: {
          bsonType: "string",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        },
        version: {
          bsonType: "string",
          pattern: "^v\\d+\\.\\d+$"
        },
        name: {
          bsonType: "string",
          minLength: 1,
          maxLength: 200
        },
        total_capacity: {
          bsonType: "int",
          minimum: 1,
          maximum: 1000000
        },
        sections: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: ["id", "name", "type", "capacity", "position", "seats"],
            properties: {
              capacity: {
                bsonType: "int",
                minimum: 1
              },
              seats: {
                bsonType: "array",
                items: {
                  bsonType: "object",
                  required: ["id", "row", "number", "coordinates", "type"]
                }
              }
            }
          }
        },
        hash: {
          bsonType: "string",
          pattern: "^[a-f0-9]{64}$" // SHA-256 hash
        }
      }
    }
  }
});

// ============================================================================
// AGGREGATION PIPELINES
// ============================================================================

/**
 * Get latest published seatmap for a venue
 */
const getLatestSeatmap = [
  {
    $match: {
      venue_id: "venue_id_here",
      is_published: true
    }
  },
  {
    $sort: { published_at: -1 }
  },
  {
    $limit: 1
  }
];

/**
 * Get seatmap statistics across all venues
 */
const getSeatmapStats = [
  {
    $group: {
      _id: "$venue_id",
      total_versions: { $sum: 1 },
      latest_version: { $max: "$version" },
      total_capacity: { $last: "$total_capacity" },
      last_updated: { $max: "$updated_at" }
    }
  },
  {
    $sort: { total_capacity: -1 }
  }
];

/**
 * Export optimized seatmap for mobile app
 */
const getMobileSeatmap = [
  {
    $match: {
      venue_id: "venue_id_here",
      is_published: true
    }
  },
  {
    $sort: { published_at: -1 }
  },
  {
    $limit: 1
  },
  {
    $project: {
      venue_id: 1,
      version: 1,
      venue_dimensions: 1,
      stage: 1,
      sections: {
        $map: {
          input: "$sections",
          as: "section",
          in: {
            id: "$$section.id",
            name: "$$section.name",
            type: "$$section.type",
            position: "$$section.position",
            display: "$$section.display",
            capacity: "$$section.capacity",
            seat_count: { $size: "$$section.seats" }
          }
        }
      },
      amenities: 1,
      emergency_exits: 1
    }
  }
];

console.log("MongoDB schema and indexes created successfully!");
console.log("Collections: seatmaps, seatmap_versions, seatmap_snapshots, seatmap_cache");
console.log("Total estimated storage for 1000 venues: ~2-5GB");
console.log("Optimized for mobile app performance and immutable audit trails");
