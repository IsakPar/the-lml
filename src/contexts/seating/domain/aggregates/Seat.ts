export type SeatProps = { eventId: string; seatId: string; version: number };
export class Seat {
  constructor(public readonly props: SeatProps) {}
}



