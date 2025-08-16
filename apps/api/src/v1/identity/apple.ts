import type { FastifyInstance } from 'fastify';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { problem } from '../../middleware/problem.js';
import { getDatabase } from '@thankful/database';

type AppleAuthRequest = { 
  // Legacy format (for backward compatibility)
  identityToken?: string;
  
  // New format from AuthenticationManager
  provider?: string;
  provider_user_id?: string;
  email?: string;
  name?: string;
  identity_token?: string;
  authorization_code?: string;
};

export async function registerAppleAuth(app: FastifyInstance) {
  const JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
  const clientId = process.env.APPLE_CLIENT_ID || '';

  app.post('/v1/auth/apple', async (req: any, reply) => {
    const body = (req.body || {}) as AppleAuthRequest;
    
    // Support both legacy and new formats
    const token = body.identity_token || body.identityToken;
    const userIdentifier = body.provider_user_id;
    const email = body.email;
    const name = body.name;
    
    if (!token) return reply.code(422).type('application/problem+json').send(
      problem(422, 'invalid_request', 'identity_token or identityToken required', 'urn:thankful:auth:apple:missing', req.ctx?.traceId)
    );
    try {
      const { payload } = await jwtVerify(token, JWKS, { issuer: 'https://appleid.apple.com', audience: clientId });
      const sub = String(payload.sub || '');
      if (!sub) return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', 'invalid token', 'urn:thankful:auth:apple:invalid', req.ctx?.traceId));
      // Use provided user identifier or fall back to token subject
      const userId = userIdentifier || sub;
      
      // Link/upsert user in DB (simplified placeholder)
      const db = getDatabase();
      await db.withTenant(String(req.ctx.orgId || ''), async (c) => {
        await c.query('INSERT INTO identity.users(id) VALUES($1) ON CONFLICT DO NOTHING', [userId]);
      });
      
      // Mint our JWT (reuse existing JwtService)
      const { JwtService } = await import('../../utils/jwt.js');
      const jwt = new JwtService();
      const access = jwt.signAccess({ 
        sub: userId, 
        userId, 
        orgId: req.ctx.orgId, 
        role: 'user', 
        permissions: ['identity.me.read'] 
      });
      const refresh = jwt.signRefresh({ 
        sub: userId, 
        userId, 
        orgId: req.ctx.orgId, 
        role: 'user', 
        permissions: ['identity.me.read'] 
      });
      
      // Enhanced response for new AuthenticationManager
      const response = {
        access_token: access,
        refresh_token: refresh,
        token_type: 'Bearer',
        expires_in: 900,
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 24 hours
        user_id: userId,
        name: name || null,
        created_at: new Date().toISOString(),
        isVerified: true // Apple accounts are always verified
      };
      
      // For backward compatibility, include user_info for legacy clients
      if (!body.provider) {
        (response as any).user_info = {
          email: email || payload.email,
          name: name
        };
      }
      
      return reply.send(response);
    } catch (e: any) {
      return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', e?.message || 'verification failed', 'urn:thankful:auth:apple:verify_failed', req.ctx?.traceId));
    }
  });
}


