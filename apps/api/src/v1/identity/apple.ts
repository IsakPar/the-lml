import type { FastifyInstance } from 'fastify';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { problem } from '../../middleware/problem.js';
import { getDatabase } from '@thankful/database';

type AppleAuthRequest = { identityToken?: string };

export async function registerAppleAuth(app: FastifyInstance) {
  const JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
  const clientId = process.env.APPLE_CLIENT_ID || '';

  app.post('/v1/auth/apple', async (req: any, reply) => {
    const body = (req.body || {}) as AppleAuthRequest;
    const token = body.identityToken;
    if (!token) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'identityToken required', 'urn:thankful:auth:apple:missing', req.ctx?.traceId));
    try {
      const { payload } = await jwtVerify(token, JWKS, { issuer: 'https://appleid.apple.com', audience: clientId });
      const sub = String(payload.sub || '');
      if (!sub) return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', 'invalid token', 'urn:thankful:auth:apple:invalid', req.ctx?.traceId));
      // Link/upsert user in DB (simplified placeholder)
      const db = getDatabase();
      await db.withTenant(String(req.ctx.orgId || ''), async (c) => {
        await c.query('INSERT INTO identity.users(id) VALUES($1) ON CONFLICT DO NOTHING', [sub]);
      });
      // Mint our JWT (reuse existing JwtService)
      const { JwtService } = await import('../../utils/jwt.js');
      const jwt = new JwtService();
      const access = jwt.signAccess({ sub, userId: sub, orgId: req.ctx.orgId, role: 'user', permissions: ['identity.me.read'] });
      const refresh = jwt.signRefresh({ sub, userId: sub, orgId: req.ctx.orgId, role: 'user', permissions: ['identity.me.read'] });
      return reply.send({ access_token: access, refresh_token: refresh, token_type: 'Bearer', expires_in: 900 });
    } catch (e: any) {
      return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', e?.message || 'verification failed', 'urn:thankful:auth:apple:verify_failed', req.ctx?.traceId));
    }
  });
}


