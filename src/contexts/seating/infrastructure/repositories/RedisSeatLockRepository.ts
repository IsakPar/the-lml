// Infrastructure adapter scaffold
import type { SeatLockRepository } from '../../../seating/application/ports/SeatLockRepository.js';

export class RedisSeatLockRepository implements SeatLockRepository {
  async acquire(_eventId: string, _seatIds: string[], _sessionId: string, _ttlMs: number): Promise<boolean> {
    return false;
  }
  async release(_eventId: string, _seatIds: string[], _sessionId: string): Promise<void> {
    return;
  }
  async extend(_eventId: string, _seatIds: string[], _sessionId: string, _ttlMs: number): Promise<number> {
    return 0;
  }
}



