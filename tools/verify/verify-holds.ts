import { request } from 'node:http';

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
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}

async function main() {
  const port = Number(process.env.PORT || 3000);
  const orgId = 'org_demo';
  const requestId = 'req-demo-1'; // constant so owner matches for extend/release

  // 1) token
  const tokenResp = await httpRequest(
    { hostname: 'localhost', port, path: '/v1/oauth/token', method: 'POST', headers: { 'content-type': 'application/json', 'x-org-id': orgId } },
    { grant_type: 'client_credentials', client_id: 'test_client', client_secret: 'test_secret' }
  );
  if (tokenResp.status !== 200) {
    console.error('token error', tokenResp.status, tokenResp.json);
    process.exit(1);
  }
  const accessToken = tokenResp.json.access_token as string;
  console.log('token ok');

  const authHeaders = { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json', 'x-org-id': orgId, 'x-request-id': requestId } as const;

  const performance_id = 'perf_demo';
  const seat_id = 'A-101-1';

  // 2) create hold
  const idemKey1 = 'ulid-demo-1';
  const createResp = await httpRequest(
    { hostname: 'localhost', port, path: '/v1/holds', method: 'POST', headers: { ...authHeaders, 'idempotency-key': idemKey1 } },
    { performance_id, seats: [seat_id], ttl_seconds: 60, sales_channel_id: 'web_uk' }
  );
  console.log('create hold', createResp.status, createResp.json);
  const hold_token = createResp.json?.hold_token as string | undefined;

  // 3) conflicting hold
  const idemKey2 = 'ulid-demo-2';
  const conflictResp = await httpRequest(
    { hostname: 'localhost', port, path: '/v1/holds', method: 'POST', headers: { ...authHeaders, 'idempotency-key': idemKey2 } },
    { performance_id, seats: [seat_id], ttl_seconds: 60, sales_channel_id: 'web_uk' }
  );
  console.log('conflict hold', conflictResp.status, conflictResp.json);

  // 4) extend hold
  const extendResp = await httpRequest(
    { hostname: 'localhost', port, path: '/v1/holds', method: 'PATCH', headers: { ...authHeaders } },
    { performance_id, seat_id, additional_seconds: 30, hold_token }
  );
  console.log('extend hold', extendResp.status, extendResp.json);

  // 5) release hold
  const holdId = `hold_${requestId}`;
  const releaseResp = await httpRequest(
    { hostname: 'localhost', port, path: `/v1/holds/${holdId}?performance_id=${encodeURIComponent(performance_id)}&seat_id=${encodeURIComponent(seat_id)}&hold_token=${encodeURIComponent(hold_token || '')}`, method: 'DELETE', headers: { ...authHeaders } }
  );
  console.log('release hold', releaseResp.status, releaseResp.json);
}

main().catch((e) => { console.error(e); process.exit(1); });


