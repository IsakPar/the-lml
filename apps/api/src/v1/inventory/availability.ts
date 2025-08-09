import type { FastifyInstance } from 'fastify';
import { problem } from '../../middleware/problem.js';

export async function registerAvailabilityRoutes(app: FastifyInstance) {
  // Snapshot availability
  app.get('/v1/performances/:perfId/availability', async (req: any, reply) => {
    const perfId = String(req.params.perfId);
    if (!perfId) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'perfId required', 'urn:thankful:inventory:invalid_perf', req.ctx?.traceId));
    // TODO: load from materialized view or compute snapshot
    const body = {
      performance_id: perfId,
      seatmap_id: 'smap_demo',
      snapshot_etag: 'W/"av-demo"',
      zones: [],
      seats: [],
      pricing: [],
      trace_id: req.ctx?.traceId,
    };
    reply.header('ETag', body.snapshot_etag);
    return body;
  });

  // SSE stream
  app.get('/v1/performances/:perfId/availability/stream', async (req: any, reply) => {
    const perfId = String(req.params.perfId);
    reply
      .header('Content-Type', 'text/event-stream')
      .header('Cache-Control', 'no-cache')
      .header('Connection', 'keep-alive');
    const send = (event: string, data: unknown) => {
      reply.raw.write(`event: ${event}\n`);
      reply.raw.write(`data: ${JSON.stringify(data)}\n\n`);
    };
    send('open', { ok: true, perf_id: perfId });
    // Keep-alive
    const iv = setInterval(() => send('ping', { t: Date.now() }), 15000);
    req.raw.on('close', () => clearInterval(iv));
  });
}


