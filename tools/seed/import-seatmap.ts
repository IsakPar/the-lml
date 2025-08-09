import { MongoClient } from 'mongodb';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve, extname } from 'node:path';

async function main() {
  const input = process.argv[2] || 'tools/seed/data/smap_demo_50.json';
  const url = process.env.MONGODB_URL || 'mongodb://localhost:27017/thankful';
  const mongo = new MongoClient(url);
  await mongo.connect();
  const db = mongo.db();
  const venues = db.collection('venues');
  const seatmaps = db.collection('seatmaps');

  const importOne = async (filePath: string) => {
    if (extname(filePath) !== '.json') return;
    const content = JSON.parse(readFileSync(resolve(filePath), 'utf8'));
    await venues.updateOne(
      { _id: content.venue_id as any },
      { $set: { _id: content.venue_id, name: content.venue_name || 'Imported Venue', tz: content.venue_tz || 'UTC' } },
      { upsert: true }
    );
    await seatmaps.updateOne(
      { _id: content.seatmap_id as any },
      { $set: { ...content, _id: content.seatmap_id, is_published: true, updated_at: new Date(), hash: content.hash || 'seed' } },
      { upsert: true }
    );
    console.log('Imported seatmap JSON:', content.seatmap_id);
  };

  const stat = statSync(resolve(input));
  if (stat.isDirectory()) {
    const files = readdirSync(resolve(input)).map((f) => resolve(input, f));
    for (const f of files) {
      await importOne(f);
    }
  } else {
    await importOne(input);
  }
  await mongo.close();
}

main().catch((e) => { console.error(e); process.exit(1); });


