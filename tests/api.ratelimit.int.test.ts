import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Fastify from 'fastify';
import supertest from 'supertest';
import { registerRequestContext } from '../apps/api/src/middleware/requestContext.js';
import { registerProblemHandler } from '../apps/api/src/middleware/problem.js';
import { registerAuth } from '../apps/api/src/middleware/auth.js';
import { registerIdentityRoutes } from '../apps/api/src/v1/identity/routes.js';

describe('Rate limit (Retry-After)', () => {
  const app = Fastify({ logger: false });
  let server: any;

  beforeAll(async () => {
    registerRequestContext(app as any);
    registerProblemHandler(app as any);
    registerAuth(app as any);
    await registerIdentityRoutes(app as any);
    await app.ready();
    server = app.server;
  });

  afterAll(async () => { await app.close(); });

  it('returns 429 with Retry-After on password grant floods', async () => {
    const doReq = () => supertest(server).post('/v1/oauth/token').send({ grant_type: 'password', username: 'u', password: 'p' });
    // Exhaust limit of 5 within window
    for (let i = 0; i < 5; i++) await doReq();
    const over = await doReq();
    expect(over.status).toBe(429);
    expect(over.headers['retry-after']).toBeDefined();
    expect(over.body.type).toBe('urn:thankful:rate_limit:exceeded');
  });
});


