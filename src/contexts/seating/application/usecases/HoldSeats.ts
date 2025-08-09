// Example use case scaffold
export type HoldSeatsInput = { eventId: string; seatIds: string[]; sessionId: string };
export type HoldSeatsOutput = { held: string[] };
export async function holdSeats(_input: HoldSeatsInput): Promise<HoldSeatsOutput> {
  return { held: [] };
}


