import type { FastifyInstance, FastifyReply } from 'fastify';

export type Problem = {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  errors?: Array<{ field: string; message: string }>;
  trace_id?: string;
};

export function problem(status: number, title: string, detail?: string, type?: string, traceId?: string): Problem {
  return {
    type: type || `about:blank`,
    title,
    status,
    detail,
    trace_id: traceId,
  };
}

export function registerProblemHandler(app: FastifyInstance) {
  app.setErrorHandler((err, req, reply: FastifyReply) => {
    const status = typeof (err as any).statusCode === 'number' ? (err as any).statusCode : 500;
    const body: Problem = {
      type: `urn:thankful:error:${status}`,
      title: err.name || 'Internal Server Error',
      status,
      detail: err.message,
      instance: req.url,
      trace_id: req.ctx?.traceId,
    };
    reply.type('application/problem+json').code(status).send(body);
  });
}


