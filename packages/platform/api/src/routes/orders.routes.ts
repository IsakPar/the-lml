import type { FastifyInstance } from 'fastify';

export async function registerOrdersRoutes(app: FastifyInstance) {
  app.post('/api/v1/orders', async (_req, reply) => {
    return reply.code(201).send({ orderId: 'stub-order-id' });
  });
}



