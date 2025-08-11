import type { FastifyInstance } from 'fastify';
import crypto from 'node:crypto';
import { MongoClient, ObjectId } from 'mongodb';
import { getDatabase } from '@thankful/database';
import { parseCursorParams, buildNextPrev, decodeCursor } from '../../utils/pagination.js';
import { problem } from '../../middleware/problem.js';

export async function registerVenueRoutes(app: FastifyInstance, deps: { mongo: MongoClient }) {
  // GET /v1/venues (cursor pagination)
  app.get('/v1/venues', async (req: any, reply) => {
    const guard = (app as any).requireScopes?.(['venues.read']);
    if (guard) {
      const resp = await guard(req, reply);
      if (resp) return resp as any;
    }
    const db = getDatabase();
    await db.withTenant(String(req.ctx.orgId || ''), async () => {});
    const { limit, starting_after } = parseCursorParams(req.query, 20, 100);
    const venues = deps.mongo.db().collection('venues');
    const filter: any = {};
    if (starting_after) {
      const cursorId = decodeCursor(starting_after);
      if (ObjectId.isValid(cursorId)) filter._id = { $gt: new ObjectId(cursorId) };
    }
    const rows = await venues.find(filter).sort({ _id: 1 }).limit(limit + 1).toArray();
    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const { next, prev } = buildNextPrev(page, { limit, hasMore });
    return { data: page, next, prev, trace_id: req.ctx?.traceId };
  });
  // GET /v1/shows (Postgres-backed list with min price)
  app.get('/v1/shows', async (req: any) => {
    const db = getDatabase();
    return await db.withTenant(String(req.ctx.orgId || ''), async (c) => {
      const rows = await c.query<any>(
        `SELECT s.id as show_id, s.title, s.poster_url, v.name as venue, 
                (SELECT MIN(amount_minor)::int FROM venues.price_tiers pt WHERE pt.show_id = s.id AND pt.tenant_id = s.tenant_id) as price_from_minor,
                (SELECT MIN(starts_at) FROM venues.performances p WHERE p.show_id = s.id AND p.status='scheduled') as next_performance_at
         FROM venues.shows s
         JOIN venues.venues v ON v.id = s.venue_id AND v.tenant_id = s.tenant_id
         ORDER BY next_performance_at NULLS LAST`);
      const data = rows.rows.map((r: any) => ({
        id: String(r.show_id),
        title: r.title,
        venue: r.venue,
        nextPerformanceAt: r.next_performance_at ? new Date(r.next_performance_at).toISOString() : null,
        posterUrl: r.poster_url,
        priceFromMinor: r.price_from_minor ?? null,
      }));
      return { data, trace_id: req.ctx?.traceId };
    });
  });

  // GET /v1/shows/:id/price-tiers
  app.get('/v1/shows/:id/price-tiers', async (req: any) => {
    const db = getDatabase();
    return await db.withTenant(String(req.ctx.orgId || ''), async (c) => {
      const rows = await c.query<any>(
        `SELECT code, name, amount_minor::int as amount_minor, color FROM venues.price_tiers WHERE show_id = $1 ORDER BY amount_minor ASC`,
        [String(req.params.id)]
      );
      return { data: rows.rows, trace_id: req.ctx?.traceId };
    });
  });

  // GET /v1/shows/:id/seatmap -> resolves mongo seatmap for next performance
  app.get('/v1/shows/:id/seatmap', async (req: any, reply) => {
    const db = getDatabase();
    return await db.withTenant(String(req.ctx.orgId || ''), async (c) => {
      const res = await c.query<any>(
        `SELECT sm.seatmap_mongo_id FROM venues.seatmaps sm 
         WHERE sm.show_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [String(req.params.id)]
      );
      const row = res.rows[0];
      if (!row) return reply.code(404).send({ error: 'not_found' });
      return { seatmapId: row.seatmap_mongo_id, trace_id: req.ctx?.traceId };
    });
  });
  // GET /v1/seatmaps/:seatmap_id or alias by key (e.g., "hamilton")
  app.get('/v1/seatmaps/:seatmapId', async (req: any, reply) => {
    const db = getDatabase();
    await db.withTenant(String(req.ctx.orgId || ''), async () => {});
    const id = String(req.params.seatmapId);
    const seatmaps = deps.mongo.db().collection('seatmaps');
    // Allow lookup by showKey alias when not an ObjectId
    let base: any;
    if (ObjectId.isValid(id)) {
      base = { _id: new ObjectId(id) };
    } else if (id && id.match(/^[a-z0-9\-]+$/)) {
      base = { showKey: id };
    } else {
      base = { _id: id };
    }
    const filter = req.ctx?.orgId ? { ...base, orgId: req.ctx.orgId } : base;
    const doc = await seatmaps.findOne(filter);
    if (!doc) {
      return reply.code(404).type('application/problem+json').send(problem(404, 'not_found', 'seatmap not found', 'urn:thankful:venues:seatmap_not_found', req.ctx?.traceId));
    }
    const etag = 'W/"' + crypto.createHash('sha1').update(JSON.stringify({ v: (doc as any).version, hash: (doc as any).hash })).digest('hex') + '"';
    reply.header('ETag', etag);
    const ifNoneMatch = req.headers['if-none-match'];
    if (ifNoneMatch && ifNoneMatch === etag) {
      return reply.code(304).send();
    }
    return { ...doc, trace_id: req.ctx?.traceId };
  });
}


