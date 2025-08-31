export interface SeatHoldReader {
  getHold(tenantId: string, performanceId: string, seatId: string): Promise<{ version: number; owner: string } | null>;
}


