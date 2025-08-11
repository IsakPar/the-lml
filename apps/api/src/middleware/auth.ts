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
    // Public static assets under /public/*
    if (req.url.startsWith('/public/')) return;

    // Allow unauthenticated for a small set (token issuance etc.)
    const publicWhitelist = new Set<string>([
      'POST /v1/oauth/token',
      'GET /v1/health',
      'GET /v1/status',
      'GET /v1/time',
      'POST /v1/payments/webhook/stripe',
      'GET /v1/verification/jwks',
    ]);
    const cleanUrl = req.url.split('?')[0];
    const key = `${req.method} ${cleanUrl}`;
    if (publicWhitelist.has(key)) return;
    // Public read for show listings and seatmaps (MVP):
    if (req.method === 'GET' && (cleanUrl === '/v1/shows' || cleanUrl.startsWith('/v1/shows/'))) return;
    if (req.method === 'GET' && (cleanUrl.startsWith('/v1/seatmaps/'))) return;

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
        permissions: Array.isArray(claims.permissions) ? claims.permissions : [],
      };
    } catch (e: any) {
      return reply.code(401).type('application/problem+json').send(problem(401, 'unauthorized', e?.message || 'invalid token', 'urn:thankful:auth:invalid_token', req.ctx?.traceId));
    }
  });

  // Simple scope guard decorator on instance
  (app as any).requireScopes = (required: string[]) => async (req: FastifyRequest, reply: FastifyReply) => {
    const perms = (req.user?.permissions || []) as string[];
    const ok = required.every((r) => perms.includes(r) || perms.includes('*'));
    if (!ok) {
      return reply.code(403).type('application/problem+json').send(problem(403, 'forbidden', 'missing required scope', 'urn:thankful:auth:forbidden', (req as any).ctx?.traceId));
    }
  };
}


