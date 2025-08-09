import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

function buildSeat(sectionId: string, rowLabel: string, seatNum: number, x: number, y: number) {
  return {
    id: `${sectionId}-${rowLabel}-${seatNum}`,
    row: rowLabel,
    number: seatNum,
    coordinates: { x, y, width: 8, height: 8 },
    type: 'standard',
    is_accessible: false,
    is_companion_seat: false,
    is_obstructed_view: false,
    sight_line_rating: 5,
    distance_to_stage_meters: 20,
    viewing_angle_degrees: 90,
    suggested_price_tier: 'pl_5999',
  };
}

function generate(seatmapId: string, venueId: string, rows: number, cols: number) {
  const seats: any[] = [];
  const startRow = 101;
  for (let r = 0; r < rows; r++) {
    const rowLabel = String(startRow + r);
    for (let c = 1; c <= cols; c++) {
      const x = c * 10;
      const y = (r + 1) * 10;
      seats.push(buildSeat('A', rowLabel, c, x, y));
    }
  }
  const doc = {
    seatmap_id: seatmapId,
    venue_id: venueId,
    version: 'v1',
    name: `Generated ${rows * cols} seats`,
    venue_dimensions: { width: 1000, height: 600, units: 'px', scale_factor: 1 },
    sections: [
      {
        id: 'A',
        name: 'Section A',
        type: 'reserved',
        position: { x: 0, y: 0, width: 100, height: 100, rotation: 0 },
        display: { color: '#cccccc', text_color: '#000000', border_color: '#333333', opacity: 1, display_order: 1 },
        capacity: rows * cols,
        seats,
      },
    ],
  };
  return doc;
}

async function main() {
  const outPath = resolve(process.argv[2] || 'tools/seed/data/smap_demo_50.json');
  const rows = Number(process.argv[3] || 5);
  const cols = Number(process.argv[4] || 10);
  const seatmapId = process.argv[5] || 'smap_demo_50';
  const venueId = process.argv[6] || 'venue_demo_50';
  const doc = generate(seatmapId, venueId, rows, cols);
  writeFileSync(outPath, JSON.stringify(doc, null, 2));
  // eslint-disable-next-line no-console
  console.log(`Wrote ${rows * cols} seats to ${outPath}`);
}

main().catch((e) => { console.error(e); process.exit(1); });


