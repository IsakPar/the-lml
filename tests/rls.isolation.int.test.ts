import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { getDatabase, MigrationRunner } from '@thankful/database';

describe('RLS isolation (two tenants)', () => {
  const t1 = '00000000-0000-0000-0000-000000000001';
  const t2 = '00000000-0000-0000-0000-000000000002';

  beforeAll(async () => {
    const db = getDatabase();
    const r = new MigrationRunner(db);
    await r.runMigrations();
    // Switch connection user to non-super role for test if DATABASE_URL_TEST is provided
    process.env.DATABASE_URL = process.env.DATABASE_URL_TEST || process.env.DATABASE_URL || '';
  });

  afterAll(async () => {
    const db = getDatabase();
    await db.close();
  });

  it('tenant cannot read other tenant rows', async () => {
    const db = getDatabase();
    let id1 = '';
    let id2 = '';
    await db.withTenant(t1, async (c) => {
      const res = await c.query<{ id: string }>("INSERT INTO orders.orders(status, total_minor, currency) VALUES ('pending', 1, 'USD') RETURNING id");
      id1 = res.rows[0].id;
    });
    await db.withTenant(t2, async (c) => {
      const res = await c.query<{ id: string }>("INSERT INTO orders.orders(status, total_minor, currency) VALUES ('pending', 1, 'USD') RETURNING id");
      id2 = res.rows[0].id;
    });
    await db.withTenant(t1, async (c) => {
      const res = await c.query("SELECT id FROM orders.orders WHERE id = $1", [id2]);
      expect(res.rows.length).toBe(0);
    });
    // And tenant 2 cannot see tenant 1 row
    await db.withTenant(t2, async (c) => {
      const res = await c.query("SELECT id FROM orders.orders WHERE id = $1", [id1]);
      expect(res.rows.length).toBe(0);
    });
  });
});


