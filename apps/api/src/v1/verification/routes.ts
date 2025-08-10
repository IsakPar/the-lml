import type { FastifyInstance } from 'fastify';
import crypto from 'node:crypto';
import { getDatabase } from '@thankful/database';
import { problem } from '../../middleware/problem.js';

type IssueRequest = { order_id: string; performance_id: string; seat_id: string };

// NOTE: For MVP we use a per-tenant HMAC signing (demo). Upgrade to KMS-backed Ed25519 and JWKS in prod.
const SECRET = process.env.TICKET_SIGNING_SECRET || 'dev-ticket-secret';

export async function registerVerificationRoutes(app: FastifyInstance) {
  // POST /v1/tickets/issue -> returns signed payload for QR
  app.post('/v1/tickets/issue', async (req: any, reply) => {
    const guard = (app as any).requireScopes?.(['tickets.issue']);
    if (guard) { const resp = await guard(req, reply); if (resp) return resp as any; }
    if (!req.ctx?.orgId) return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    const body = (req.body || {}) as IssueRequest;
    if (!body.order_id || !body.performance_id || !body.seat_id) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'order_id, performance_id, seat_id required', 'urn:thankful:verification:invalid_issue', req.ctx?.traceId));
    const jti = `tkt_${crypto.randomBytes(8).toString('hex')}`;
    const payload = { ver: 1, tenant_id: req.ctx.orgId, order_id: body.order_id, performance_id: body.performance_id, seat_id: body.seat_id, jti, iat: Math.floor(Date.now()/1000) };
    const json = JSON.stringify(payload);
    const sig = crypto.createHmac('sha256', SECRET).update(json).digest('base64url');
    const token = `hmac.v1.${sig}.${Buffer.from(json).toString('base64url')}`;
    const db = getDatabase();
    await db.withTenant(String(req.ctx.orgId), async (c) => {
      await c.query('INSERT INTO ticketing.tickets(order_id, performance_id, seat_id, jti) VALUES ($1,$2,$3,$4)', [body.order_id, body.performance_id, body.seat_id, jti]);
    });
    return reply.code(201).send({ ticket_token: token });
  });

  // GET /v1/verification/jwks (placeholder for future public keys)
  app.get('/v1/verification/jwks', async (_req, reply) => {
    return reply.send({ keys: [] });
  });

  // POST /v1/verification/redeem -> online redemption
  app.post('/v1/verification/redeem', async (req: any, reply) => {
    const { ticket_token } = req.body || {};
    if (typeof ticket_token !== 'string' || !ticket_token.startsWith('hmac.v1.')) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'ticket_token required', 'urn:thankful:verification:invalid_token', req.ctx?.traceId));
    const parts = ticket_token.split('.');
    if (parts.length !== 4) return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_token', 'bad token format', 'urn:thankful:verification:bad_format', req.ctx?.traceId));
    const sig = parts[2];
    const payloadB64 = parts[3];
    const json = Buffer.from(payloadB64, 'base64url').toString('utf8');
    const check = crypto.createHmac('sha256', SECRET).update(json).digest('base64url');
    if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(check))) return reply.code(401).type('application/problem+json').send(problem(401, 'invalid_signature', 'signature mismatch', 'urn:thankful:verification:invalid_signature', req.ctx?.traceId));
    let payload: any;
    try { payload = JSON.parse(json); } catch { return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_payload', 'not json', 'urn:thankful:verification:bad_payload', req.ctx?.traceId)); }
    const tenant = String(payload.tenant_id || '');
    const jti = String(payload.jti || '');
    if (!tenant || !jti) return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_payload', 'missing fields', 'urn:thankful:verification:missing_fields', req.ctx?.traceId));
    const db = getDatabase();
    let status = 'issued';
    await db.withTenant(tenant, async (c) => {
      const res = await c.query<{ status: string }>('SELECT status FROM ticketing.tickets WHERE jti=$1', [jti]);
      if (res.rows.length === 0) return reply.code(404).type('application/problem+json').send(problem(404, 'not_found', 'ticket not found', 'urn:thankful:verification:not_found', req.ctx?.traceId));
      const s = res.rows[0].status;
      if (s === 'redeemed') { status = 'redeemed'; return; }
      if (s === 'revoked') { status = 'revoked'; return; }
      await c.query('UPDATE ticketing.tickets SET status=$1, redeemed_at=now() WHERE jti=$2', ['redeemed', jti]);
      status = 'redeemed';
    });
    return reply.send({ jti, status });
  });
}


