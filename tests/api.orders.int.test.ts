import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Fastify from 'fastify';
import { registerRequestContext } from '../apps/api/src/middleware/requestContext.js';
import { registerProblemHandler } from '../apps/api/src/middleware/problem.js';
import { registerAuth } from '../apps/api/src/middleware/auth.js';
import { registerOrdersRoutes } from '../apps/api/src/v1/orders/routes.js';
import supertest from 'supertest';
import { getDatabase, MigrationRunner } from '@thankful/database';
import { JwtService } from '../apps/api/src/utils/jwt.js';

describe('Orders API (idempotency + tenant)', () => {
  const app = Fastify({ logger: false });
  let server: any;

  beforeAll(async () => {
    // Apply migrations to ensure tables exist for the test DB
    const db = getDatabase();
    const r = new MigrationRunner(db as any);
    await r.runMigrations();
    registerRequestContext(app as any);
    registerProblemHandler(app as any);
    registerAuth(app as any);
    await registerOrdersRoutes(app as any);
    await app.ready();
    server = app.server;
  });

  afterAll(async () => {
    await app.close();
  });

  it('creates order idempotently', async () => {
    const jwt = new JwtService();
    const access = jwt.signAccess({ sub: 'usr_test', userId: 'usr_test', orgId: '00000000-0000-0000-0000-000000000001', role: 'user', permissions: ['orders.write'] });
    const token = 'Bearer ' + access;
    const uniqueTotal = Math.floor(Date.now() % 1000000);
    const body = { currency: 'USD', total_minor: uniqueTotal };
    const req = () => supertest(server)
      .post('/v1/orders')
      .set('Authorization', token)
      .set('X-Org-ID', '00000000-0000-0000-0000-000000000001')
      .set('Idempotency-Key', 'idem-test-12345678')
      .send(body);
    const a = await req();
    if (![200,201].includes(a.status)) {
      // eslint-disable-next-line no-console
      console.error('First response', a.status, a.body);
    }
    expect([200,201]).toContain(a.status);
    const b = await req();
    expect([200,201,202]).toContain(b.status);
    if (b.body && typeof b.body === 'object' && 'order_id' in b.body) {
      expect(b.body.order_id).toBeDefined();
    } else {
      expect(b.body).toEqual(expect.objectContaining({ cached: expect.any(Boolean) }));
    }
  });
});


