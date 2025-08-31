import { describe, it, expect } from 'vitest';
import { AcquireSeatLocks, type AcquireSeatLocksCommand } from './usecases/AcquireSeatLocks.js';
import type { SeatLockService, AcquireLocksRequest } from './ports/SeatLockService.js';
import { Result } from '@thankful/shared';

type RateLimit = { allowed: boolean; retryAfterSeconds?: number };

describe('AcquireSeatLocks', () => {
  const fakeRateLimit = () => ({
    async checkLimit() { return Result.success<RateLimit, any>({ allowed: true }); },
    async recordAttempt() { /* noop */ }
  });
  const fakeEventValidation = () => ({
    async validateEventForBooking() { return Result.success({ isOnSale: true, maxTicketsPerUser: 8 }); }
  });
  const fakeSeatLockService = () => ({
    async getUserLocks() { return Result.success([]); },
    async acquireLocks(req: AcquireLocksRequest) {
      return Result.success({
        acquiredLocks: req.seatIds.map((s) => ({ seatId: s, userId: req.userId, fencingToken: 'v:o', acquiredAt: new Date(), expiresAt: new Date(Date.now() + 120000), extensionCount: 0, maxExtensions: 1 })),
        failedSeats: [],
        queuedSeats: [],
        fencingToken: 'v:o',
        expiresAt: new Date(Date.now() + 120000),
        canExtend: true
      });
    }
  } as unknown as SeatLockService);

  it('fails validation when required fields are missing', async () => {
    const uc = new AcquireSeatLocks(fakeSeatLockService(), fakeRateLimit() as any, fakeEventValidation() as any);
    const res = await uc.execute({ eventId: '', seatIds: [], userId: '' } as unknown as AcquireSeatLocksCommand);
    expect(res.isFailure).toBe(true);
    if (res.isFailure) expect(res.error.type).toBe('VALIDATION_ERROR');
  });

  it('succeeds and returns acquired seats summary', async () => {
    const uc = new AcquireSeatLocks(fakeSeatLockService(), fakeRateLimit() as any, fakeEventValidation() as any);
    const res = await uc.execute({ eventId: 'perf_x', seatIds: ['A1','A2'], userId: 'u1' });
    expect(res.isSuccess).toBe(true);
    if (res.isSuccess) {
      expect(res.value.summary.acquired).toBe(2);
      expect(res.value.masterFencingToken).toBeDefined();
      expect(res.value.acquiredSeats[0].seatId).toBe('A1');
    }
  });
});
