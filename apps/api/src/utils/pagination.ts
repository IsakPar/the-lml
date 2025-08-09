export type CursorPageParams = {
  limit?: number;
  starting_after?: string;
  ending_before?: string;
};

export function parseCursorParams(query: any, defaultLimit = 20, maxLimit = 100): Required<CursorPageParams> {
  const limitRaw = Number(query?.limit ?? defaultLimit);
  const limit = Math.max(1, Math.min(maxLimit, isFinite(limitRaw) ? limitRaw : defaultLimit));
  const starting_after = typeof query?.starting_after === 'string' ? query.starting_after : '';
  const ending_before = typeof query?.ending_before === 'string' ? query.ending_before : '';
  return { limit, starting_after, ending_before };
}

export function encodeCursor(value: string): string {
  return Buffer.from(value).toString('base64url');
}

export function decodeCursor(cursor: string): string {
  try { return Buffer.from(cursor, 'base64url').toString('utf8'); } catch { return ''; }
}

export function buildNextPrev<T extends { id?: string; _id?: any }>(items: T[], opts: { limit: number; hasMore: boolean }): { next: string | null; prev: string | null } {
  if (items.length === 0) return { next: null, prev: null };
  const first = (items[0].id || String(items[0]._id)) as string;
  const last = (items[items.length - 1].id || String(items[items.length - 1]._id)) as string;
  const next = opts.hasMore ? encodeCursor(last) : null;
  const prev = encodeCursor(first);
  return { next, prev };
}


