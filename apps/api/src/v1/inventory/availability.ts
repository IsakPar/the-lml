import type { FastifyInstance } from 'fastify';
import { problem } from '../../middleware/problem.js';
import { createClient as createRedisClient } from 'redis';
import { broadcast, addClient, removeClient } from '../../utils/sse.js';
import { MongoClient } from 'mongodb';

export async function registerAvailabilityRoutes(app: FastifyInstance) {
  // Snapshot availability (seat- and section-level from seatmap + Redis locks)
  app.get('/v1/performances/:perfId/availability', async (req: any, reply) => {
    const perfId = String(req.params.perfId);
    if (!perfId) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'perfId required', 'urn:thankful:inventory:invalid_perf', req.ctx?.traceId));
    if (!req.ctx.orgId) return reply.code(422).type('application/problem+json').send(problem(422, 'missing_header', 'X-Org-ID required', 'urn:thankful:header:missing_org', req.ctx?.traceId));
    const tenant = req.ctx.orgId as string;
    const seatmapId = String(req.query?.seatmap_id || '');
    if (!seatmapId) return reply.code(422).type('application/problem+json').send(problem(422, 'invalid_request', 'seatmap_id required', 'urn:thankful:inventory:missing_seatmap', req.ctx?.traceId));

    // Load seatmap from Mongo (tenant-scoped)
    let seatmap: any;
    try {
      const mongo = (req.server as any).mongo as MongoClient | undefined;
      if (!mongo) throw new Error('mongo client not available');
      const seatmaps = mongo.db().collection('seatmaps');
      const filter: any = { _id: seatmapId as any };
      if (req.ctx?.orgId) filter.orgId = req.ctx.orgId;
      seatmap = await seatmaps.findOne(filter);
      if (!seatmap) return reply.code(404).type('application/problem+json').send(problem(404, 'not_found', 'seatmap not found', 'urn:thankful:inventory:seatmap_not_found', req.ctx?.traceId));
    } catch (e: any) {
      return reply.code(500).type('application/problem+json').send(problem(500, 'mongo_error', String(e?.message || e), 'urn:thankful:infra:mongo', req.ctx?.traceId));
    }

    const sections: Array<any> = Array.isArray(seatmap.sections) ? seatmap.sections : [];
    const allSeats: Array<any> = sections.flatMap((s: any) => Array.isArray(s.seats) ? s.seats : []);

    // Build seat→section map
    const seatToSection = new Map<string, string>();
    for (const sec of sections) {
      for (const s of (sec.seats || [])) seatToSection.set(s.id, sec.id);
    }

    // Query Redis for current held seats via MGET
    const client = createRedisClient({ url: String(process.env.REDIS_URL || 'redis://localhost:6379') });
    await client.connect();
    const seatIds = allSeats.map((s) => s.id);
    const redisKeys = seatIds.map((sid) => `hold:v1:{${tenant}:${perfId}}:${sid}`);
    const values = seatIds.length ? await client.mGet(redisKeys) : [];
    await client.quit();
    const heldSet = new Set<string>();
    values.forEach((v, i) => { if (v) heldSet.add(seatIds[i]); });

    const seatsOut = allSeats.map((s) => ({
      seat_id: s.id,
      section: seatToSection.get(s.id),
      row: s.row,
      status: heldSet.has(s.id) ? 'held' : 'available',
      price_level_id: s.suggested_price_tier,
      attributes: { accessible: !!s.is_accessible, companion: !!s.is_companion_seat, obstructed: !!s.is_obstructed_view },
    }));

    const zonesOut: Array<any> = sections.map((sec: any) => {
      const list = (sec.seats || []) as Array<any>;
      const available = list.filter((x) => !heldSet.has(x.id)).length;
      const held = list.length - available;
      return { zone_id: sec.id, type: sec.type || 'reserved', capacity: list.length, available, held };
    });

    // Pricing summary (simple aggregation by suggested_price_tier)
    const pricingMap = new Map<string, any>();
    for (const s of allSeats) {
      const pl = s.suggested_price_tier;
      if (pl && !pricingMap.has(pl)) pricingMap.set(pl, { price_level_id: pl, name: String(pl), face_value: { amount: '0', currency: process.env.DEFAULT_CURRENCY || 'USD' }, fees: [] });
    }

    // Strong-ish ETag from seatmap hash + held count
    const etag = `W/"av-${seatmap.hash || 'h0'}-${heldSet.size}"`;
    const body = {
      performance_id: perfId,
      seatmap_id: seatmapId,
      zones: zonesOut,
      seats: seatsOut,
      pricing: Array.from(pricingMap.values()),
      snapshot_etag: etag,
      trace_id: req.ctx?.traceId,
    };
    reply.header('ETag', etag);
    return body;
  });

  // SSE stream
  app.get('/v1/performances/:perfId/availability/stream', async (req: any, reply) => {
    const perfId = String(req.params.perfId);
    reply
      .header('Content-Type', 'text/event-stream')
      .header('Cache-Control', 'no-cache')
      .header('Connection', 'keep-alive');
    addClient(reply.raw);
    reply.raw.write(`event: open\n`);
    reply.raw.write(`data: ${JSON.stringify({ ok: true, perf_id: perfId })}\n\n`);
    const iv = setInterval(() => reply.raw.write(`event: ping\n` + `data: ${JSON.stringify({ t: Date.now() })}\n\n`), 15000);
    req.raw.on('close', () => { clearInterval(iv); removeClient(reply.raw); });
  });
}


