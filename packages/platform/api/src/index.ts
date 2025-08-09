import Fastify from 'fastify';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { getRegistry } from '../../../metrics/src/index.js';
import { loadConfig } from '../../../config/src/index.js';
import { registerRoutes } from './routes/index.js';

export async function createServer() {
  const app = Fastify({ logger: false });
  const env = loadConfig();

  // raw-body plugin is registered route-scoped in payments.routes

  // Liveness
  app.get('/livez', async () => ({ status: 'ok' }));

  // Readiness (no external network calls)
  app.get('/readyz', async () => {
    // TODO: check PG, Redis, Mongo connectivity via adapters once wired
    // For now, ensure Stripe webhook secret present
    if (!env.STRIPE_WEBHOOK_SECRET) {
      return { status: 'degraded', missing: ['STRIPE_WEBHOOK_SECRET'] };
    }
    return { status: 'ready' };
  });

  // Metrics
  app.get('/metrics', async (_req: FastifyRequest, reply: FastifyReply) => {
    const registry = getRegistry();
    reply.header('Content-Type', registry.contentType);
    return registry.metrics();
  });

  await registerRoutes(app);

  return app;
}


