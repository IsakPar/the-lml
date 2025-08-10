import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { counter, histogram } from '@thankful/metrics';

const httpRequests = counter({ name: 'http_requests_total', help: 'Total number of HTTP requests', labelNames: ['method', 'route', 'status'] as any });
const httpLatency = histogram({ name: 'http_request_duration_ms', help: 'HTTP request duration in ms', labelNames: ['method', 'route', 'status'] as any, buckets: [5, 10, 25, 50, 100, 200, 400, 800, 1600] });

export function registerHttpMetrics(app: FastifyInstance) {
  app.addHook('onRequest', async (req: FastifyRequest) => {
    (req as any)._start = process.hrtime.bigint();
  });
  app.addHook('onResponse', async (req: FastifyRequest, reply: FastifyReply) => {
    const start = (req as any)._start as bigint | undefined;
    const end = process.hrtime.bigint();
    const ms = start ? Number(end - start) / 1_000_000 : 0;
    const route = (req as any).routeOptions?.url || req.url.split('?')[0];
    const labels: any = { method: req.method, route, status: String(reply.statusCode) };
    httpRequests.inc(labels);
    httpLatency.observe(labels, ms);
  });
}
