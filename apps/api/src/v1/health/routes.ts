import type { FastifyInstance } from 'fastify';

export async function registerHealthRoutes(app: FastifyInstance) {
  app.get('/v1/health', async (_req, _reply) => ({ status: 'ok' }));

  app.get('/v1/status', async (req: any, reply) => {
    const body = {
      service: 'thankful-api',
      version: process.env.APP_VERSION || '0.0.0',
      region: process.env.REGION || 'local',
      dependencies: {
        postgres: process.env.DATABASE_URL ? 'configured' : 'missing',
        redis: process.env.REDIS_URL ? 'configured' : 'missing',
        mongodb: process.env.MONGODB_URL ? 'configured' : 'missing',
      },
      time: new Date().toISOString(),
      trace_id: req.ctx?.traceId,
    } as any;
    reply.header('Cache-Control', 'no-store');
    return body;
  });

  app.get('/v1/time', async (req, reply) => {
    reply.header('Cache-Control', 'no-store');
    return { now: new Date().toISOString(), trace_id: req.ctx?.traceId };
  });
}


