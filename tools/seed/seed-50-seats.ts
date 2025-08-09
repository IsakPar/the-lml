import { MongoClient, ObjectId } from 'mongodb';

async function main() {
  const url = process.env.MONGODB_URL || 'mongodb://localhost:27017/thankful';
  const mongo = new MongoClient(url);
  await mongo.connect();
  const db = mongo.db();

  const venues = db.collection('venues');
  const seatmaps = db.collection('seatmaps');

  const venueId = 'venue_demo_50';
  await venues.updateOne({ _id: venueId as any }, { $set: { _id: venueId, name: 'Demo Venue 50', tz: 'Europe/London' } }, { upsert: true });

  const seatmapId = 'smap_demo_50';
  const sections = [
    { id: 'A', name: 'A', type: 'reserved', position: { x: 0, y: 0, width: 100, height: 100, rotation: 0 }, display: { color: '#ccc', text_color: '#000', border_color: '#333', opacity: 1, display_order: 1 }, capacity: 50, seats: [] as any[] },
  ];
  // 5 rows x 10 seats
  for (let r = 1; r <= 5; r++) {
    for (let s = 1; s <= 10; s++) {
      sections[0].seats.push({ id: `A-${r}-${s}`, row: String(r), number: s, coordinates: { x: s * 10, y: r * 10, width: 8, height: 8 }, type: 'standard', is_accessible: false, is_companion_seat: false, is_obstructed_view: false, sight_line_rating: 5, distance_to_stage_meters: 20, viewing_angle_degrees: 90, suggested_price_tier: 'pl_5999' });
    }
  }

  await seatmaps.updateOne({ _id: seatmapId as any }, {
    $set: {
      _id: seatmapId,
      venue_id: venueId,
      version: 'v1',
      name: 'Demo 50 seats',
      total_capacity: 50,
      venue_dimensions: { width: 1000, height: 600, units: 'px', scale_factor: 1 },
      sections,
      is_published: true,
      updated_at: new Date(),
      hash: 'demo',
    }
  }, { upsert: true });

  console.log('Seeded demo venue and seatmap: ', { venueId, seatmapId });
  await mongo.close();
}

main().catch((e) => { console.error(e); process.exit(1); });


