import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Fastify from 'fastify';
import supertest from 'supertest';
import { registerRequestContext } from '../apps/api/src/middleware/requestContext.js';
import { registerProblemHandler } from '../apps/api/src/middleware/problem.js';
import { registerAuth } from '../apps/api/src/middleware/auth.js';
import { registerInventoryRoutes } from '../apps/api/src/v1/inventory/routes.js';
// ensure metrics registry is constructed once across suite
import '../packages/metrics/src/index.js';
import { JwtService } from '../apps/api/src/utils/jwt.js';

describe('Inventory fencing (If-Match required)', () => {
  const app = Fastify({ logger: false });
  let server: any;
  const tenant = '00000000-0000-0000-0000-000000000001';
  let auth: string;

  beforeAll(async () => {
    registerRequestContext(app as any);
    registerProblemHandler(app as any);
    registerAuth(app as any);
    await registerInventoryRoutes(app as any);
    await app.ready();
    server = app.server;
    const jwt = new JwtService();
    auth = 'Bearer ' + jwt.signAccess({ sub: 'usr_test', userId: 'usr_test', orgId: tenant, role: 'user', permissions: ['inventory.holds:write'] });
  });

  afterAll(async () => { await app.close(); });

  it('returns 412 when missing hold_token on extend', async () => {
    const resp = await supertest(server)
      .patch('/v1/holds')
      .set('Authorization', auth)
      .set('X-Org-ID', tenant)
      .set('Idempotency-Key', 'idem-extend-1')
      .send({ performance_id: 'perf1', seat_id: 's1', additional_seconds: 30 });
    expect(resp.status).toBe(412);
    expect(resp.body.type).toBe('urn:thankful:inventory:precondition');
  });
});


