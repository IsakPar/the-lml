import Fastify from 'fastify';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { getRegistry } from '../../../metrics/src/index.js';
// config check removed for readiness impl
import { registerRoutes } from './routes/index.js';

export async function createServer() {
  const app = Fastify({ logger: false });
  // env loading handled elsewhere if needed

  // raw-body plugin is registered route-scoped in payments.routes

  // Liveness
  app.get('/livez', async () => ({ status: 'ok' }));

  // Readiness handled in health/ready.ts handler (mounted by routes/system if needed)

  // Metrics
  app.get('/metrics', async (_req: FastifyRequest, reply: FastifyReply) => {
    const registry = getRegistry();
    reply.header('Content-Type', registry.contentType);
    return registry.metrics();
  });

  await registerRoutes(app);

  return app;
}


