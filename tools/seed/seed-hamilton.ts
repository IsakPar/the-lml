/**
 * Seed Hamilton @ Victoria Palace Theatre using custom seatmap JSON.
 * Usage: tsx tools/seed/seed-hamilton.ts
 */
import fs from 'fs/promises';
import path from 'path';
import { MongoClient } from 'mongodb';
import { getDatabase } from '../../packages/database/src/index.js';

async function main() {
  const orgId = process.env.SEED_ORG_ID || '00000000-0000-0000-0000-000000000001';
  const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/thankful';
  const mongo = new MongoClient(String(mongoUrl));
  await mongo.connect();
  const mdb = mongo.db();

  const seatmapPath = path.resolve(process.cwd(), 'public/seatmaps/hamilton_simple_coords.json');
  const raw = await fs.readFile(seatmapPath, 'utf-8');
  const json = JSON.parse(raw);

  // Enhance seats with missing fields for proper rendering including row/number
  if (json.seats && Array.isArray(json.seats)) {
    const sectionColors: {[key: string]: string} = {
      'Central Front': '#FF6B6B',
      'Upper Left Box': '#4ECDC4', 
      'Upper Right Box': '#45B7D1',
      'Lower Central': '#96CEB4',
      'Lower Left Box': '#FFEAA7',
      'Lower Right Box': '#DDA0DD',
      'Bottom Left Section': '#98D8C8',
      'Bottom Right Section': '#FFAAA5'
    };
    
    // First enhance seats with basic fields and optimize layout
    json.seats = json.seats.map((seat: any, index: number) => ({
      ...seat,
      id: seat.id || `seat_${index + 1}`,
      width: seat.width || 1.2,
      height: seat.height || 1.2,
      priceLevelId: seat.priceLevelId || 'standard',
      colorHex: sectionColors[seat.section] || '#6B7280',
      x: seat.x + 5.0,  // Add horizontal padding to prevent edge cramping
      y: seat.y - 8.0   // Move all seats up for intimate but balanced gap with stage
    }));

    // Now add realistic row/number based on coordinates within each section
    const seatsBySection = json.seats.reduce((acc: any, seat: any, globalIndex: number) => {
      if (!acc[seat.section]) acc[seat.section] = [];
      acc[seat.section].push({...seat, globalIndex});
      return acc;
    }, {});

    const enhancedSeats: any[] = [];
    
    // Process each section to generate realistic row/seat numbers
    for (const [sectionName, sectionSeats] of Object.entries(seatsBySection) as [string, any[]][]) {
      // Sort by y (depth from stage), then by x (left to right)
      sectionSeats.sort((a, b) => a.y === b.y ? a.x - b.x : a.y - b.y);
      
      // Group into rows by y-coordinate (seats with similar y are in same row)
      const rows: any[][] = [];
      let currentRow: any[] = [];
      let lastY = -1;
      const yTolerance = 1.0; // seats within 1.0 units are same row (reduced from 1.8)
      
      for (const seat of sectionSeats) {
        if (lastY === -1 || Math.abs(seat.y - lastY) <= yTolerance) {
          currentRow.push(seat);
          lastY = seat.y;
        } else {
          if (currentRow.length > 0) {
            rows.push([...currentRow]);
          }
          currentRow = [seat];
          lastY = seat.y;
        }
      }
      if (currentRow.length > 0) rows.push(currentRow);
      
      // Assign row letters and seat numbers
      rows.forEach((rowSeats, rowIndex) => {
        // Sort seats in row from left to right
        rowSeats.sort((a, b) => a.x - b.x);
        const rowLetter = String.fromCharCode(65 + rowIndex); // A, B, C...
        
        rowSeats.forEach((seat, seatIndex) => {
          const seatNumber = String(seatIndex + 1);
          enhancedSeats.push({
            ...seat,
            row: rowLetter,
            number: seatNumber
          });
        });
      });
    }
    
    // Replace the original seats with enhanced ones
    json.seats = enhancedSeats;
  }

  // Insert seatmap doc
  const smDoc = {
    orgId,
    showKey: 'hamilton',
    venue: 'Victoria Palace Theatre',
    createdAt: new Date(),
    schema: 'custom:v1',
    data: json
  };
  const result = await mdb.collection('seatmaps').replaceOne(
    { orgId, showKey: 'hamilton' },
    smDoc,
    { upsert: true }
  );
  const insertedId = result.upsertedId || (await mdb.collection('seatmaps').findOne({ orgId, showKey: 'hamilton' }))?._id;

  const showDoc = {
    orgId,
    key: 'hamilton',
    title: 'Hamilton',
    venue: 'Victoria Palace Theatre',
    nextPerformanceAt: '2025-09-15T19:30:00Z',
    posterUrl: '/public/posters/hamilton.jpg',
    priceFromMinor: 2750, // £27.50 - restricted view tier
    seatmapId: String(insertedId),
    createdAt: new Date(),
  };
  await mdb.collection('shows').updateOne({ orgId, key: 'hamilton' }, { $set: showDoc }, { upsert: true });

  // Also seed Postgres entities
  const db = getDatabase();
  await db.withTenant(orgId, async (c) => {
    const venue = await c.query<{ id: string }>(
      `INSERT INTO venues.venues(name, tz) VALUES ($1,'Europe/London')
       ON CONFLICT (tenant_id, name) DO UPDATE SET tz=EXCLUDED.tz RETURNING id`,
      ['Victoria Palace Theatre']
    );
    const venueId = venue.rows[0].id;
    const show = await c.query<{ id: string }>(
      `INSERT INTO venues.shows(venue_id, title, poster_url) VALUES ($1,$2,$3)
       ON CONFLICT (tenant_id, venue_id, title) DO UPDATE SET poster_url=EXCLUDED.poster_url RETURNING id`,
      [venueId, 'Hamilton', '/public/posters/hamilton.jpg']
    );
    const showId = show.rows[0].id;
    const perf = await c.query<{ id: string }>(
      `INSERT INTO venues.performances(show_id, starts_at) VALUES ($1,$2)
       RETURNING id`,
      [showId, '2025-09-15T19:30:00Z']
    );
    const performanceId = perf.rows[0].id;
    // Price tiers for DENSE seatmap layout (matches JSON pricing tiers)
    await c.query(
      `INSERT INTO venues.price_tiers(show_id, code, name, amount_minor, color)
       VALUES ($1,'premium','Premium',12500,'#8B5CF6'),
              ($1,'standard','Standard',8500,'#6366F1'),
              ($1,'elevated_premium','Elevated Premium',9500,'#10B981'),
              ($1,'elevated_standard','Elevated Standard',6500,'#F59E0B'),
              ($1,'budget','Budget',4500,'#EF4444'),
              ($1,'restricted','Restricted View',3500,'#6B7280')
       ON CONFLICT (tenant_id, show_id, code) DO UPDATE SET name=EXCLUDED.name, amount_minor=EXCLUDED.amount_minor, color=EXCLUDED.color`,
      [showId]
    );
    // Link to Mongo seatmap
    await c.query(
      `INSERT INTO venues.seatmaps(show_id, performance_id, seatmap_mongo_id, version)
       VALUES ($1,$2,$3,1)`,
      [showId, performanceId, String(insertedId)]
    );

    // Seed seat inventory from the simple coordinate seatmap
    console.log(`Seeding ${json.seats?.length || 0} seats to inventory (simple coordinate seatmap)...`);
    if (json.seats && Array.isArray(json.seats)) {
      // Clear existing seats for this performance to avoid duplicates
      await c.query(
        `DELETE FROM inventory.seat_catalog WHERE performance_id = $1`,
        [performanceId]
      );
      
      // Batch insert seats in chunks for better performance (seats already have row/number from MongoDB processing)
      const chunkSize = 100;
      for (let i = 0; i < json.seats.length; i += chunkSize) {
        const chunk = json.seats.slice(i, i + chunkSize);
        const values = chunk.map((seat: any) => {
          const seatId = seat.id || `seat_${i + 1}`;
          const row = seat.row || 'A';
          const number = seat.number || '1';
          const priceTier = seat.priceLevelId || 'standard';
          return `('${performanceId}','${seatId}','${seat.section}','${row}','${number}','${priceTier}')`;
        }).join(',');
        
        await c.query(
          `INSERT INTO inventory.seat_catalog(performance_id, seat_id, section, row, number, price_tier_code)
           VALUES ${values}
           ON CONFLICT (tenant_id, performance_id, seat_id) DO NOTHING`
        );
      }
      
      // Initialize all seats as available in seat_state
      await c.query(
        `INSERT INTO inventory.seat_state(performance_id, seat_id, state, updated_at)
         SELECT performance_id, seat_id, 'available', NOW()
         FROM inventory.seat_catalog 
         WHERE performance_id = $1
         ON CONFLICT (tenant_id, performance_id, seat_id) 
         DO UPDATE SET state = 'available', updated_at = NOW()`,
        [performanceId]
      );
    }
  });

  console.log('Seeded Hamilton with simple coordinate seatmap (' + json.total_seats + ' seats) - id:', String(insertedId));
  await mongo.close();
}

main().catch((e) => { console.error(e); process.exit(1); });


