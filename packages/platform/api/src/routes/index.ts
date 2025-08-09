import type { FastifyInstance } from 'fastify';
import { registerPaymentsRoutes } from './payments.routes.js';
import { registerSeatingRoutes } from './seating.routes.js';
import { registerOrdersRoutes } from './orders.routes.js';
import { registerCatalogRoutes } from './catalog.routes.js';

export async function registerRoutes(app: FastifyInstance) {
  await registerPaymentsRoutes(app);
  await registerSeatingRoutes(app);
  await registerOrdersRoutes(app);
  await registerCatalogRoutes(app);
}


