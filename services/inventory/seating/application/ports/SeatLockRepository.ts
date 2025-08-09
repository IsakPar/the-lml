// Interface definition scaffold
export interface SeatLockRepository {
  acquire(eventId: string, seatIds: string[], sessionId: string, ttlMs: number): Promise<boolean>;
  release(eventId: string, seatIds: string[], sessionId: string): Promise<void>;
  extend(eventId: string, seatIds: string[], sessionId: string, ttlMs: number): Promise<number>;
}



