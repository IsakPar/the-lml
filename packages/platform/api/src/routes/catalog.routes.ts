import type { FastifyInstance } from 'fastify';

export async function registerCatalogRoutes(app: FastifyInstance) {
  app.get('/api/v1/events/:id/layout', async (_req, reply) => {
    return reply.code(200).send({ layout: 'stub' });
  });
}



