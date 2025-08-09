import http from 'node:http';

function request<T = any>(options: http.RequestOptions & { path: string; method: string; headers?: Record<string, string> }, body?: any): Promise<{ s: number; h: any; j: T }>
{
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try {
          resolve({ s: res.statusCode || 0, h: res.headers, j: data ? JSON.parse(data) : undefined });
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function main() {
  const port = Number(process.env.PORT || 3000);
  const base = { hostname: 'localhost', port };

  const tok = await request<{ access_token: string }>({ ...base, path: '/v1/oauth/token', method: 'POST', headers: { 'content-type': 'application/json' } }, {
    grant_type: 'client_credentials', client_id: 'test_client', client_secret: 'test_secret'
  });
  if (tok.s !== 200) throw new Error('token failed ' + tok.s);
  const at = tok.j.access_token;
  const auth = 'Bearer ' + at;

  const headers = { 'authorization': auth, 'content-type': 'application/json', 'x-org-id': 'org_demo' };
  const snap = await request<any>({ ...base, path: '/v1/performances/perf_demo/availability?seatmap_id=smap_demo_50', method: 'GET', headers });
  console.log('availability status:', snap.s);
  console.log('zones[0]:', JSON.stringify(snap.j?.zones?.[0], null, 2));
  console.log('seats sample:', JSON.stringify(snap.j?.seats?.slice(0, 5), null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });


