import { createClient } from 'redis';
import { seatKey } from '../redis/adapter.js';
import type { SeatHoldReader } from '../../application/ports/SeatHoldReader.js';

export class RedisSeatHoldReader implements SeatHoldReader {
  constructor(private url: string) {}

  async getHold(tenantId: string, performanceId: string, seatId: string): Promise<{ version: number; owner: string } | null> {
    const client = createClient({ url: this.url });
    await client.connect();
    try {
      const key = seatKey(tenantId, performanceId, seatId);
      const val = await client.get(key);
      if (!val) return null;
      const idx = val.indexOf(':');
      const vStr = idx >= 0 ? val.slice(0, idx) : '';
      const oStr = idx >= 0 ? val.slice(idx + 1) : '';
      const version = Number(vStr);
      if (!Number.isFinite(version) || !oStr) return null;
      return { version, owner: oStr };
    } finally {
      await client.quit();
    }
  }
}


