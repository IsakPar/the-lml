import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { JwtService, extractBearer } from '../utils/jwt.js';
import { problem } from './problem.js';

declare module 'fastify' {
  interface FastifyRequest {
    user?: {
      userId?: string;
      clientId?: string;
      role?: string;
      permissions?: string[];
    };
  }
}

export function registerAuth(app: FastifyInstance) {
  const jwt = new JwtService();

  app.addHook('preHandler', async (req: FastifyRequest, reply: FastifyReply) => {
    // Public routes under /v1/public are skipped
    if (req.url.startsWith('/v1/public')) return;

    // Allow unauthenticated for a small set (token issuance etc.)
    const publicWhitelist = new Set<string>([
      'POST /v1/oauth/token',
      'GET /v1/health',
      'GET /v1/status',
      'GET /v1/time',
    ]);
    const key = `${req.method} ${req.url}`.split('?')[0];
    if (publicWhitelist.has(key)) return;

    const token = extractBearer(req.headers.authorization as string | undefined);
    if (!token) {
      return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', 'missing bearer token', 'urn:thankful:auth:missing_token', req.ctx?.traceId));
    }
    try {
      const claims = jwt.verify(token);
      req.user = {
        userId: claims.userId,
        clientId: claims.clientId,
        role: claims.role,
        permissions: claims.permissions,
      };
    } catch (e: any) {
      return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', e?.message || 'invalid token', 'urn:thankful:auth:invalid_token', req.ctx?.traceId));
    }
  });
}


