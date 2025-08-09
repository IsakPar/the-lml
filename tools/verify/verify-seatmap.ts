import { request } from 'node:http';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function httpRequest(opts: any, body?: any): Promise<{ status: number; headers: any; json: any }> {
  return new Promise((resolvePromise, reject) => {
    const req = request(opts, (res) => {
      const chunks: Uint8Array[] = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        try {
          const text = Buffer.concat(chunks).toString('utf8');
          const json = text ? JSON.parse(text) : null;
          resolvePromise({ status: res.statusCode || 0, headers: res.headers, json });
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    if (body) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}

async function main() {
  const file = process.argv[2] || 'tools/seed/data/smap_demo_50.json';
  const expected = JSON.parse(readFileSync(resolve(file), 'utf8'));
  const port = Number(process.env.PORT || 3000);

  // 1) fetch token via client_credentials
  const tokenResp = await httpRequest({ hostname: 'localhost', port, path: '/v1/oauth/token', method: 'POST', headers: { 'content-type': 'application/json' } }, { grant_type: 'client_credentials', client_id: 'test_client', client_secret: 'test_secret' });
  if (tokenResp.status !== 200) {
    console.error('Failed to get token:', tokenResp.status, tokenResp.json);
    process.exit(1);
  }
  const accessToken = tokenResp.json.access_token as string;

  // 2) fetch seatmap
  const seatResp = await httpRequest({ hostname: 'localhost', port, path: `/v1/seatmaps/${expected.seatmap_id}`, method: 'GET', headers: { authorization: `Bearer ${accessToken}` } });
  if (seatResp.status !== 200) {
    console.error('Failed to fetch seatmap:', seatResp.status, seatResp.json);
    process.exit(1);
  }
  const actual = seatResp.json;
  // naive compare: seat counts and first/last coordinates
  const expSeats = expected.sections[0].seats;
  const actSeats = actual.sections?.[0]?.seats || [];
  console.log('Counts:', { expected: expSeats.length, actual: actSeats.length });
  // Print all seats with coordinates for terminal inspection
  const rows = actSeats.map((s: any) => ({ seat_id: s.id || s.seat_id || s.seatId, coordinates: s.coordinates }));
  for (const r of rows) {
    console.log(`${r.seat_id}: x=${r.coordinates?.x}, y=${r.coordinates?.y}, w=${r.coordinates?.width}, h=${r.coordinates?.height}`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });


