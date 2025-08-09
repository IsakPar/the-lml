import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

export type RequestContext = {
  orgId?: string;
  brandId?: string;
  salesChannelId?: string;
  requestId: string;
  traceId: string;
};

declare module 'fastify' {
  interface FastifyRequest {
    ctx: RequestContext;
  }
}

export function registerRequestContext(app: FastifyInstance) {
  app.addHook('onRequest', async (req: FastifyRequest, reply: FastifyReply) => {
    const requestId = (req.headers['x-request-id'] as string) || `req_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
    const traceId = (req.headers['x-trace-id'] as string) || requestId;
    const orgId = (req.headers['x-org-id'] as string) || undefined;
    const brandId = (req.headers['x-brand-id'] as string) || undefined;
    const salesChannelId = (req.headers['x-sales-channel-id'] as string) || undefined;

    req.ctx = { requestId, traceId, orgId, brandId, salesChannelId };

    reply.header('X-Request-ID', requestId);
    reply.header('X-Trace-ID', traceId);
  });
}


