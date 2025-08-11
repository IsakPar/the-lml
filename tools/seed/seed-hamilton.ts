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

  const seatmapPath = path.resolve(process.cwd(), 'public/seatmaps/custom_seat_map.json');
  const raw = await fs.readFile(seatmapPath, 'utf-8');
  const json = JSON.parse(raw);

  // Insert seatmap doc
  const smDoc = {
    orgId,
    showKey: 'hamilton',
    venue: 'Victoria Palace Theatre',
    createdAt: new Date(),
    schema: 'custom:v1',
    data: json
  };
  const { insertedId } = await mdb.collection('seatmaps').insertOne(smDoc);

  const showDoc = {
    orgId,
    key: 'hamilton',
    title: 'Hamilton',
    venue: 'Victoria Palace Theatre',
    nextPerformanceAt: '2025-09-15T19:30:00Z',
    posterUrl: '/public/posters/hamilton.jpg',
    priceFromMinor: 7500,
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
    // Price tiers
    await c.query(
      `INSERT INTO venues.price_tiers(show_id, code, name, amount_minor, color)
       VALUES ($1,'premium','Premium',16000,'#d4af37'),
              ($1,'standard','Standard',12000,'#4ea1ff'),
              ($1,'value','Value',7500,'#6ee787')
       ON CONFLICT (tenant_id, show_id, code) DO UPDATE SET name=EXCLUDED.name, amount_minor=EXCLUDED.amount_minor, color=EXCLUDED.color`,
      [showId]
    );
    // Link to Mongo seatmap
    await c.query(
      `INSERT INTO venues.seatmaps(show_id, performance_id, seatmap_mongo_id, version)
       VALUES ($1,$2,$3,1)`,
      [showId, performanceId, String(insertedId)]
    );
  });

  console.log('Seeded Hamilton with seatmap id', String(insertedId));
  await mongo.close();
}

main().catch((e) => { console.error(e); process.exit(1); });


