import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { randomUUID } from 'node:crypto';
import Fastify from 'fastify';
import { registerRequestContext } from '../apps/api/src/middleware/requestContext.js';
import { registerProblemHandler } from '../apps/api/src/middleware/problem.js';
import { registerAuth } from '../apps/api/src/middleware/auth.js';
import { registerOrdersRoutes } from '../apps/api/src/v1/orders/routes.js';
import { registerInventoryRoutes } from '../apps/api/src/v1/inventory/routes.js';
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
    await registerInventoryRoutes(app as any);
    await registerOrdersRoutes(app as any);
    await app.ready();
    server = app.server;
  });

  afterAll(async () => {
    await app.close();
  });

  it('creates order idempotently (with hold + email)', async () => {
    const jwt = new JwtService();
    const access = jwt.signAccess({ sub: 'usr_test', userId: 'usr_test', orgId: '00000000-0000-0000-0000-000000000001', role: 'user', permissions: ['orders.write','inventory.holds:write'] });
    const token = 'Bearer ' + access;
    const tenant = '00000000-0000-0000-0000-000000000001';
    const perfId = randomUUID();
    const seatId = 'S1';
    // Ensure seat exists as available in DB
    const db = getDatabase();
    await db.withTenant(tenant, async (c: any) => {
      await c.query('DELETE FROM inventory.seat_state WHERE performance_id=$1 AND seat_id=$2', [perfId, seatId]);
      await c.query("INSERT INTO inventory.seat_state(performance_id, seat_id, state, updated_at) VALUES ($1,$2,'available', NOW())", [perfId, seatId]);
    });
    // Acquire a hold to satisfy order precondition
    const hold = await supertest(server)
      .post('/v1/holds')
      .set('Authorization', token)
      .set('X-Org-ID', tenant)
      .set('Idempotency-Key', 'idem-hold-order')
      .send({ performance_id: perfId, seats: [seatId], ttl_seconds: 120 });
    expect([200,201]).toContain(hold.status);
    const holdToken = String(hold.body?.hold_token || '');
    expect(holdToken).toContain(':');
    const body = { performance_id: perfId, seat_ids: [seatId], customer_email: 'e@example.com', currency: 'USD' };
    const req = () => supertest(server)
      .post('/v1/orders')
      .set('Authorization', token)
      .set('X-Org-ID', tenant)
      .set('Idempotency-Key', 'idem-order-11111111')
      .set('X-Seat-Hold-Token', holdToken)
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

  it('returns 409 when seats are not held by this buyer', async () => {
    const jwt = new JwtService();
    const access = jwt.signAccess({ sub: 'usr_test', userId: 'usr_test', orgId: '00000000-0000-0000-0000-000000000001', role: 'user', permissions: ['orders.write','inventory.holds:write'] });
    const token = 'Bearer ' + access;
    const tenant = '00000000-0000-0000-0000-000000000001';
    const perfId = randomUUID();
    const seatId = 'A1';
    // Ensure seat exists as available in DB
    const db = getDatabase();
    await db.withTenant(tenant, async (c: any) => {
      await c.query('DELETE FROM inventory.seat_state WHERE performance_id=$1 AND seat_id=$2', [perfId, seatId]);
      await c.query("INSERT INTO inventory.seat_state(performance_id, seat_id, state, updated_at) VALUES ($1,$2,'available', NOW())", [perfId, seatId]);
    });
    // Acquire a hold with a different requestId (simulating another buyer)
    const holdRes = await supertest(server)
      .post('/v1/holds')
      .set('Authorization', token)
      .set('X-Org-ID', tenant)
      .set('Idempotency-Key', 'idem-hold-1')
      .send({ performance_id: perfId, seats: [seatId], ttl_seconds: 120 });
    expect([200,201]).toContain(holdRes.status);
    const foreignHoldToken = String(holdRes.body?.hold_token || '');
    expect(foreignHoldToken).toContain(':');

    // Now attempt to create an order with same seat but using a different (invalid) token
    const order = await supertest(server)
      .post('/v1/orders')
      .set('X-Org-ID', tenant)
      .set('Idempotency-Key', 'idem-order-409')
      // Missing or wrong X-Seat-Hold-Token should lead to 412/409; send a mismatched token
      .set('X-Seat-Hold-Token', '0:someone-else')
      .send({ performance_id: perfId, seat_ids: [seatId], customer_email: 'e@example.com', currency: 'USD' });
    expect([409,412]).toContain(order.status);
  });
});


