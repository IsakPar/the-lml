import type { FastifyInstance } from 'fastify';
import crypto from 'node:crypto';
import { MongoClient, ObjectId } from 'mongodb';
import { parseCursorParams, buildNextPrev, decodeCursor } from '../../utils/pagination.js';
import { problem } from '../../middleware/problem.js';

export async function registerVenueRoutes(app: FastifyInstance, deps: { mongo: MongoClient }) {
  // GET /v1/venues (cursor pagination)
  app.get('/v1/venues', async (req: any, reply) => {
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
  // GET /v1/seatmaps/:seatmap_id
  app.get('/v1/seatmaps/:seatmapId', async (req: any, reply) => {
    const id = String(req.params.seatmapId);
    const seatmaps = deps.mongo.db().collection('seatmaps');
    const filter = ObjectId.isValid(id) ? { _id: new ObjectId(id) } : { _id: id } as any;
    const doc = await seatmaps.findOne(filter);
    if (!doc) {
      return reply.code(404).type('application/problem+json').send(problem(404, 'not_found', 'seatmap not found', 'urn:thankful:venues:seatmap_not_found', req.ctx?.traceId));
    }
    const etag = 'W/"' + crypto.createHash('sha1').update(JSON.stringify({ v: doc.version, hash: doc.hash })).digest('hex') + '"';
    reply.header('ETag', etag);
    const ifNoneMatch = req.headers['if-none-match'];
    if (ifNoneMatch && ifNoneMatch === etag) {
      return reply.code(304).send();
    }
    return { ...doc, trace_id: req.ctx?.traceId };
  });
}


