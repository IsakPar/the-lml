import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Fastify from 'fastify';
import supertest from 'supertest';
import { registerRequestContext } from '../apps/api/src/middleware/requestContext.js';
import { registerProblemHandler } from '../apps/api/src/middleware/problem.js';
import { registerAuth } from '../apps/api/src/middleware/auth.js';
import { registerVerificationRoutes } from '../apps/api/src/v1/verification/routes.js';
import { getDatabase, MigrationRunner } from '@thankful/database';
import { JwtService } from '../apps/api/src/utils/jwt.js';
import { rotateKeyPair } from '@thankful/verification';

describe('Verification API', () => {
  const app = Fastify({ logger: false });
  let server: any;
  const tenant = '00000000-0000-0000-0000-000000000001';

  function tokenFor(perms: string[]) {
    const jwt = new JwtService();
    return 'Bearer ' + jwt.signAccess({ sub: 'usr_verifier', userId: 'usr_verifier', orgId: tenant, role: 'verifier', permissions: perms });
  }

  beforeAll(async () => {
    const db = getDatabase();
    const r = new MigrationRunner(db as any);
    await r.runMigrations();
    registerRequestContext(app as any);
    registerProblemHandler(app as any);
    registerAuth(app as any);
    await registerVerificationRoutes(app as any);
    await app.ready();
    server = app.server;
  });

  afterAll(async () => { await app.close(); });

  async function issueTicket(authz: string) {
    const body = { order_id: '00000000-0000-0000-0000-000000000123', performance_id: 'perf_1', seat_id: 'A-1' };
    const res = await supertest(server)
      .post('/v1/tickets/issue')
      .set('Authorization', authz)
      .set('X-Org-ID', tenant)
      .send(body);
    expect(res.status).toBe(201);
    expect(res.body.ticket_token).toBeDefined();
    return res.body.ticket_token as string;
  }

  it('issues and redeems a valid ticket', async () => {
    const tkn = await issueTicket(tokenFor(['tickets.issue', 'tickets.redeem']));
    const r = await supertest(server)
      .post('/v1/verification/redeem')
      .set('Authorization', tokenFor(['tickets.redeem']))
      .set('X-Org-ID', tenant)
      .send({ ticket_token: tkn });
    expect(r.status).toBe(200);
    expect(r.body).toEqual(expect.objectContaining({ status: 'redeemed', jti: expect.any(String) }));
  });

  it('rejects tampered signature', async () => {
    const tkn = await issueTicket(tokenFor(['tickets.issue']));
    const parts = tkn.split('.');
    // Tamper payload bytes so signature verification must fail
    const payloadB64 = parts[4];
    const json = Buffer.from(payloadB64, 'base64url').toString('utf8');
    const obj = JSON.parse(json);
    obj.seat_id = 'B-999';
    const tamperedPayload = Buffer.from(JSON.stringify(obj)).toString('base64url');
    parts[4] = tamperedPayload;
    const bad = parts.join('.');
    const r = await supertest(server)
      .post('/v1/verification/redeem')
      .set('Authorization', tokenFor(['tickets.redeem']))
      .set('X-Org-ID', tenant)
      .send({ ticket_token: bad });
    expect(r.status).toBe(401);
    expect(r.body.type).toContain('invalid_signature');
  });

  it('rejects expired ticket', async () => {
    // Build an expired token by issuing and then modifying payload exp backwards
    const tkn = await issueTicket(tokenFor(['tickets.issue']));
    const [alg, ver, kid, sig, payloadB64] = tkn.split('.');
    const json = Buffer.from(payloadB64, 'base64url').toString('utf8');
    const payload = JSON.parse(json);
    payload.exp = Math.floor(Date.now() / 1000) - 10;
    const newJson = JSON.stringify(payload);
    // resign with current key
    const { privateKey } = rotateKeyPair(); // ensure a new key; but we'll rebuild token with new kid/signature
    const newSig = (await import('node:crypto')).default.sign(null, Buffer.from(newJson), privateKey).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
    const expired = `${alg}.${ver}.${kid}.${newSig}.${Buffer.from(newJson).toString('base64url')}`;
    const r = await supertest(server)
      .post('/v1/verification/redeem')
      .set('Authorization', tokenFor(['tickets.redeem']))
      .set('X-Org-ID', tenant)
      .send({ ticket_token: expired });
    expect([400,401]).toContain(r.status);
  });

  it('rejects double scan with 409', async () => {
    const tkn = await issueTicket(tokenFor(['tickets.issue', 'tickets.redeem']));
    const ok = await supertest(server)
      .post('/v1/verification/redeem')
      .set('Authorization', tokenFor(['tickets.redeem']))
      .set('X-Org-ID', tenant)
      .send({ ticket_token: tkn });
    expect(ok.status).toBe(200);
    const dup = await supertest(server)
      .post('/v1/verification/redeem')
      .set('Authorization', tokenFor(['tickets.redeem']))
      .set('X-Org-ID', tenant)
      .send({ ticket_token: tkn });
    expect(dup.status).toBe(409);
  });

  it('rejects tenant mismatch', async () => {
    const tkn = await issueTicket(tokenFor(['tickets.issue']));
    const r = await supertest(server)
      .post('/v1/verification/redeem')
      .set('Authorization', tokenFor(['tickets.redeem']))
      .set('X-Org-ID', '00000000-0000-0000-0000-000000000002')
      .send({ ticket_token: tkn });
    expect(r.status).toBe(409);
  });

  it('exposes JWKS', async () => {
    const r = await supertest(server)
      .get('/v1/verification/jwks');
    expect(r.status).toBe(200);
    expect(Array.isArray(r.body.keys)).toBe(true);
    expect(r.body.keys[0]).toEqual(expect.objectContaining({ kty: 'OKP', crv: 'Ed25519', kid: expect.any(String), x: expect.any(String) }));
  });
});


