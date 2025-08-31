import { describe, it, expect } from 'vitest';
import { VerifySeatHoldsUseCase } from './usecases/VerifySeatHolds.js';

class InMemoryReader {
  private map = new Map<string, { version: number; owner: string }>();
  set(t: string, p: string, s: string, v: number, o: string) { this.map.set(`${t}:${p}:${s}`, { version: v, owner: o }); }
  async getHold(t: string, p: string, s: string) { return this.map.get(`${t}:${p}:${s}`) ?? null; }
}

describe('VerifySeatHoldsUseCase', () => {
  it('returns invalid_token when token is malformed', async () => {
    const r = new InMemoryReader();
    const uc = new VerifySeatHoldsUseCase(r as any);
    const res = await uc.execute({ tenantId: 't', performanceId: 'p', seatIds: ['A1'], holdToken: 'bad' });
    expect(res.ok).toBe(false);
    if (res.ok === false && 'reason' in res) expect(res.reason).toBe('invalid_token');
  });

  it('returns ok when all seats held by same owner', async () => {
    const r = new InMemoryReader();
    r.set('t','p','A1', 1, 'o');
    r.set('t','p','A2', 1, 'o');
    const uc = new VerifySeatHoldsUseCase(r as any);
    const res = await uc.execute({ tenantId: 't', performanceId: 'p', seatIds: ['A1','A2'], holdToken: '1:o' });
    expect(res.ok).toBe(true);
  });

  it('returns conflicts when any seat is not held by owner', async () => {
    const r = new InMemoryReader();
    r.set('t','p','A1', 1, 'o');
    const uc = new VerifySeatHoldsUseCase(r as any);
    const res = await uc.execute({ tenantId: 't', performanceId: 'p', seatIds: ['A1','A2'], holdToken: '1:o' });
    expect(res.ok).toBe(false);
    if (res.ok === false && 'conflicts' in res) expect(res.conflicts).toContain('A2');
  });
});


