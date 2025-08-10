import Fastify from 'fastify';
import { readyzHandler } from './health/ready.js';
import { registerHttpMetrics } from './health/metrics.js';
import { serializeMetrics } from '../../../packages/metrics/src/index.js';
import { registerRequestContext } from './middleware/requestContext.js';
import { registerProblemHandler } from './middleware/problem.js';
import { registerHealthRoutes } from './v1/health/routes.js';
import { registerVenueRoutes } from './v1/venues/routes.js';
import { registerInventoryRoutes } from './v1/inventory/routes.js';
import { registerAvailabilityRoutes } from './v1/inventory/availability.js';
import { registerIdentityRoutes } from './v1/identity/routes.js';
import { registerOrdersRoutes } from './v1/orders/routes.js';
import { registerPaymentsRoutes } from './v1/payments/routes.js';
import { registerVerificationRoutes } from './v1/verification/routes.js';
import { registerAuth } from './middleware/auth.js';
import { MongoClient } from 'mongodb';

async function main() {
  const app = Fastify({ logger: true });
  app.get('/livez', async () => ({ status: 'ok' }));
  app.get('/readyz', readyzHandler);
  app.get('/metrics', async (_req, reply) => {
    const body = await serializeMetrics();
    reply.type('text/plain; version=0.0.4');
    return body;
  });

  // Register base middleware
  registerRequestContext(app);
  registerProblemHandler(app);
  registerHttpMetrics(app);
  registerAuth(app);

  // Mount v1 routes
  await registerHealthRoutes(app);
  await registerIdentityRoutes(app);

  // Shared clients (can be moved to DI later)
  const mongo = new MongoClient(String(process.env.MONGODB_URL || 'mongodb://localhost:27017/thankful'));
  await mongo.connect();
  (app as any).mongo = mongo;
  // Ensure essential Mongo indexes (idempotent)
  try {
    const db = mongo.db();
    await db.collection('seatmaps').createIndex({ orgId: 1, _id: 1 });
  } catch {}
  await registerVenueRoutes(app, { mongo });
  await registerInventoryRoutes(app);
  await registerAvailabilityRoutes(app);
  await registerOrdersRoutes(app);
  await registerPaymentsRoutes(app);
  await registerVerificationRoutes(app);
  // eslint-disable-next-line no-console
  console.log('routes mounted: /livez, /readyz, /metrics, /v1/*');
  const port = Number(process.env.PORT ?? 3000);
  await app.listen({ port, host: '0.0.0.0' });
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});



