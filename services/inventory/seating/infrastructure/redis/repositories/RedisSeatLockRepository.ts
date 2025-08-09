// Infrastructure adapter scaffold (legacy path — not used; kept to unblock build)
type SeatLockRepository = {
  acquire: (eventId: string, seatIds: string[], sessionId: string, ttlMs: number) => Promise<boolean>;
  release: (eventId: string, seatIds: string[], sessionId: string) => Promise<void>;
  extend: (eventId: string, seatIds: string[], sessionId: string, ttlMs: number) => Promise<number>;
};

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



