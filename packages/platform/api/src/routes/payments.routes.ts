import type { FastifyInstance } from 'fastify';
import rawBody from 'fastify-raw-body';

export async function registerPaymentsRoutes(app: FastifyInstance) {
  await app.register(rawBody, { field: 'rawBody', global: false, runFirst: true });

  app.route({
    method: 'POST',
    url: '/api/v1/payments/webhook',
    config: { rawBody: true },
    handler: async (req, reply) => {
      const sig = req.headers['stripe-signature'];
      const raw = (req as any).rawBody as Buffer | undefined;
      if (!raw || !sig) {
        return reply.code(400).send({ error: 'missing_signature_or_body' });
      }
      // TODO: verify using Stripe SDK with raw buffer
      return reply.code(200).send({ ok: true });
    }
  });
}


