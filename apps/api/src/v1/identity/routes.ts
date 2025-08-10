import type { FastifyInstance } from 'fastify';
import { JwtService } from '../../utils/jwt.js';
import { getDatabase } from '@thankful/database';
import { problem } from '../../middleware/problem.js';
import { createRateLimitMiddleware } from '@thankful/ratelimit';

export async function registerIdentityRoutes(app: FastifyInstance) {
  // Tighter limiter for password grant (per user/IP)
  const loginLimiter = createRateLimitMiddleware({ limit: 5, windowSeconds: 60, keyFn: (req: any) => `login:${req.body?.username || ''}:${req.ip}` });
  const jwt = new JwtService();

  // OAuth2.1 token endpoint (simplified: password/client_credentials for MVP)
  app.post('/v1/oauth/token', { preHandler: async (req: any, reply) => {
    if (req.body?.grant_type === 'password') {
      await (loginLimiter as any)(req, reply);
    }
  } }, async (req: any, reply) => {
    const { grant_type, client_id, client_secret, username, password } = req.body || {};

    if (grant_type === 'client_credentials') {
      // TODO: validate client_id/secret from store
      const accessToken = jwt.signAccess({ sub: client_id, clientId: client_id, orgId: req.ctx.orgId, role: 'service', permissions: ['*'] });
      const refreshToken = jwt.signRefresh({ sub: client_id, clientId: client_id, orgId: req.ctx.orgId, role: 'service', permissions: ['*'] });
      return reply.send({ access_token: accessToken, refresh_token: refreshToken, token_type: 'Bearer', expires_in: 900 });
    }

    if (grant_type === 'password') {
      // Apply request-level throttle (per user/IP) via rateLimit middleware in future; here we add minimal sleep on repeated failures
      // TODO: validate user with Identity service
      if (!username || !password) {
        return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_request', 'username and password required', 'urn:thankful:oauth:invalid_request', req.ctx?.traceId));
      }
      // Optional: apply a tighter rate limit policy in middleware later
      const userId = `usr_${Buffer.from(username).toString('hex').slice(0, 8)}`;
      const accessToken = jwt.signAccess({ sub: userId, userId, orgId: req.ctx.orgId, role: 'user', permissions: ['identity.me.read'] });
      const refreshToken = jwt.signRefresh({ sub: userId, userId, orgId: req.ctx.orgId, role: 'user', permissions: ['identity.me.read'] });
      return reply.send({ access_token: accessToken, refresh_token: refreshToken, token_type: 'Bearer', expires_in: 900 });
    }

    return reply.code(400).type('application/problem+json').send(problem(400, 'unsupported_grant_type', 'Only client_credentials and password supported in MVP', 'urn:thankful:oauth:unsupported_grant', req.ctx?.traceId));
  });

  // Current user
  app.get('/v1/users/me', async (req: any, reply) => {
    const guard = (app as any).requireScopes?.(['identity.me.read']);
    if (guard) {
      const resp = await guard(req, reply);
      if (resp) return resp as any;
    }
    const db = getDatabase();
    if (!req.user?.userId) {
      return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', 'no user context', 'urn:thankful:auth:unauthorized', req.ctx?.traceId));
    }
    // Ensure tenant is set for any downstream repo calls (future repos)
    await db.withTenant(String(req.ctx.orgId || ''), async () => {});
    return reply.send({ user_id: req.user.userId, role: req.user.role || 'user', org_id: req.ctx.orgId, brand_id: req.ctx.brandId, sales_channel_id: req.ctx.salesChannelId, trace_id: req.ctx?.traceId });
  });
}


