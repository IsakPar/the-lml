import type { FastifyInstance } from 'fastify';

export async function registerSeatingRoutes(app: FastifyInstance) {
  app.post('/api/v1/seats/hold', async (_req, reply) => {
    return reply.code(202).send({ status: 'accepted' });
  });
  app.post('/api/v1/seats/release', async (_req, reply) => {
    return reply.code(200).send({ status: 'released' });
  });
}



