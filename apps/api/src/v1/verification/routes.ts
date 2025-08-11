import type { FastifyInstance } from 'fastify';
import crypto from 'node:crypto';
import { getOrCreateKeyPair, signPayloadEd25519, exportJwk, verifyPayloadEd25519, getPublicKeyByKid, getPublicJwks } from '@thankful/verification';
import { getDatabase } from '@thankful/database';
import { problem } from '../../middleware/problem.js';
import { createRateLimitMiddleware } from '@thankful/ratelimit';
const log = (event: string, fields: Record<string, unknown> = {}) => {
  try { console.log(JSON.stringify({ event, ...fields })); } catch {}
};
import { context, trace } from '@opentelemetry/api';

type IssueRequest = { order_id: string; performance_id: string; seat_id: string };

// NOTE: For MVP we use a per-tenant HMAC signing (demo). Upgrade to KMS-backed Ed25519 and JWKS in prod.
const SECRET = process.env.TICKET_SIGNING_SECRET || 'dev-ticket-secret';

export async function registerVerificationRoutes(app: FastifyInstance) {
  const rl = createRateLimitMiddleware({ limit: 10, windowSeconds: 60 });
  const rlRead = createRateLimitMiddleware({ limit: 60, windowSeconds: 60 });
  // POST /v1/tickets/issue -> returns signed payload for QR (Ed25519)
  app.post('/v1/tickets/issue', { preHandler: rl as any }, async (req: any, reply) => {
    const tracer = trace.getTracer('api');
    return await tracer.startActiveSpan('tickets.issue', async (span) => {
    const guard = (app as any).requireScopes?.(['tickets.issue']);
    if (guard) { const resp = await guard(req, reply); if (resp) return resp as any; }
    if (!req.ctx?.orgId) return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    const body = (req.body || {}) as IssueRequest;
    if (!body.order_id || !body.performance_id || !body.seat_id) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'order_id, performance_id, seat_id required', 'urn:thankful:verification:invalid_issue', req.ctx?.traceId));
    const jti = `tkt_${crypto.randomBytes(8).toString('hex')}`;
    const nowSec = Math.floor(Date.now()/1000);
    const ttlSec = Number(process.env.TICKET_TTL_SECONDS || 2 * 3600);
    const payload = { ver: 1, tenant_id: req.ctx.orgId, order_id: body.order_id, performance_id: body.performance_id, seat_id: body.seat_id, jti, iat: nowSec, exp: nowSec + ttlSec };
    const json = JSON.stringify(payload);
    const { kid, privateKey } = getOrCreateKeyPair();
    const sig = signPayloadEd25519(privateKey, Buffer.from(json));
    const token = `ed25519.v1.${kid}.${sig}.${Buffer.from(json).toString('base64url')}`;
    const db = getDatabase();
    await db.withTenant(String(req.ctx.orgId), async (c) => {
      await c.query('INSERT INTO ticketing.tickets(order_id, performance_id, seat_id, jti) VALUES ($1,$2,$3,$4)', [body.order_id, body.performance_id, body.seat_id, jti]);
    });
    log('ticket.issue', { tenantId: req.ctx.orgId, jti, performanceId: body.performance_id, seatId: body.seat_id, requestId: req.ctx.requestId });
      span.setAttribute('tenantId', String(req.ctx.orgId));
      span.setAttribute('jti', jti);
      span.end();
      return reply.code(201).send({ ticket_token: token });
    });
  });

  // GET /v1/verification/jwks (Ed25519 public keys)
  app.get('/v1/verification/jwks', { preHandler: rlRead as any }, async (_req, reply) => {
    const jwks = getPublicJwks();
    return reply.send(jwks);
  });

  // POST /v1/verification/redeem -> online redemption
  app.post('/v1/verification/redeem', { preHandler: rl as any }, async (req: any, reply) => {
    const tracer = trace.getTracer('api');
    return await tracer.startActiveSpan('tickets.redeem', async (span) => {
    const guard = (app as any).requireScopes?.(['tickets.redeem']);
    if (guard) { const resp = await guard(req, reply); if (resp) return resp as any; }
    const { ticket_token } = req.body || {};
    if (typeof ticket_token !== 'string' || !ticket_token.startsWith('ed25519.v1.')) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'ticket_token required', 'urn:thankful:verification:invalid_token', req.ctx?.traceId));
    const parts = ticket_token.split('.');
    if (parts.length !== 5) return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_token', 'bad token format', 'urn:thankful:verification:bad_format', req.ctx?.traceId));
    const kid = parts[2];
    const sig = parts[3];
    const payloadB64 = parts[4];
    const json = Buffer.from(payloadB64, 'base64url').toString('utf8');
    const pub = getPublicKeyByKid(kid) || getOrCreateKeyPair().publicKey; // fallback dev
    if (!verifyPayloadEd25519(pub, Buffer.from(json), sig)) return reply.code(401).type('application/problem+json').send(problem(401, 'invalid_signature', 'signature mismatch', 'urn:thankful:verification:invalid_signature', req.ctx?.traceId));
    let payload: any;
    try { payload = JSON.parse(json); } catch { return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_payload', 'not json', 'urn:thankful:verification:bad_payload', req.ctx?.traceId)); }
    const tenant = String(payload.tenant_id || '');
    const jti = String(payload.jti || '');
    const nowSec = Math.floor(Date.now()/1000);
    if (typeof payload.exp === 'number' && nowSec > payload.exp) {
      return reply.code(401).type('application/problem+json').send(problem(401, 'expired_ticket', 'ticket expired', 'urn:thankful:verification:expired', req.ctx?.traceId));
    }
    if (!tenant || !jti) return reply.code(400).type('application/problem+json').send(problem(400, 'invalid_payload', 'missing fields', 'urn:thankful:verification:missing_fields', req.ctx?.traceId));
    if (!req.ctx?.orgId) return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    if (String(req.ctx.orgId) !== tenant) return reply.code(409).type('application/problem+json').send(problem(409, 'tenant_mismatch', 'ticket not for this tenant', 'urn:thankful:verification:tenant_mismatch', req.ctx?.traceId));
    const db = getDatabase();
    let status = 'issued';
    await db.withTenant(tenant, async (c) => {
      const res = await c.query<{ status: string }>('SELECT status FROM ticketing.tickets WHERE jti=$1', [jti]);
      if (res.rows.length === 0) return reply.code(404).type('application/problem+json').send(problem(404, 'not_found', 'ticket not found', 'urn:thankful:verification:not_found', req.ctx?.traceId));
      const s = res.rows[0].status;
      if (s === 'redeemed') { return reply.code(409).type('application/problem+json').send(problem(409, 'already_redeemed', 'ticket already redeemed', 'urn:thankful:verification:already_redeemed', req.ctx?.traceId)); }
      if (s === 'revoked') { return reply.code(403).type('application/problem+json').send(problem(403, 'revoked', 'ticket revoked', 'urn:thankful:verification:revoked', req.ctx?.traceId)); }
      await c.query('UPDATE ticketing.tickets SET status=$1, redeemed_at=now() WHERE jti=$2', ['redeemed', jti]);
      status = 'redeemed';
    });
    log('ticket.redeem', { tenantId: tenant, jti, status, requestId: req.ctx.requestId });
      span.setAttribute('tenantId', tenant);
      span.setAttribute('jti', jti);
      span.setAttribute('status', status);
      span.end();
      return reply.send({ jti, status });
    });
  });
}


