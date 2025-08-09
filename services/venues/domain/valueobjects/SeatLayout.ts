import { ValueObject } from '@thankful/shared';
import { Coordinate } from '@thankful/shared';

interface SeatInfo {
  id: string;
  row: string;
  number: number;
  coordinates: Coordinate;
  isAccessible?: boolean;
  isPremium?: boolean;
}

interface SeatLayoutProps {
  seats: SeatInfo[];
  rows: string[];
  totalSeats: number;
}

/**
 * SeatLayout value object containing the complete seat arrangement for a section
 * Used for mobile app rendering and seat selection
 */
export class SeatLayout extends ValueObject<SeatLayoutProps> {
  private constructor(props: SeatLayoutProps) {
    super(props);
  }

  public static create(seats: SeatInfo[]): SeatLayout {
    if (seats.length === 0) {
      throw new Error('Seat layout must contain at least one seat');
    }

    // Validate seat IDs are unique
    const seatIds = seats.map(s => s.id);
    const uniqueIds = new Set(seatIds);
    if (uniqueIds.size !== seatIds.length) {
      throw new Error('All seat IDs must be unique');
    }

    // Validate coordinates are unique
    const coordinates = seats.map(s => `${s.coordinates.x},${s.coordinates.y}`);
    const uniqueCoords = new Set(coordinates);
    if (uniqueCoords.size !== coordinates.length) {
      throw new Error('All seat coordinates must be unique');
    }

    // Extract unique rows
    const rows = Array.from(new Set(seats.map(s => s.row))).sort();

    return new SeatLayout({
      seats: [...seats],
      rows,
      totalSeats: seats.length
    });
  }

  public getValue(): SeatLayoutProps {
    return this.props;
  }

  public getSeatCount(): number {
    return this.props.totalSeats;
  }

  public getRows(): string[] {
    return [...this.props.rows];
  }

  public getSeatsByRow(): Map<string, number> {
    const seatsByRow = new Map<string, number>();
    
    for (const row of this.props.rows) {
      const seatsInRow = this.props.seats.filter(s => s.row === row).length;
      seatsByRow.set(row, seatsInRow);
    }

    return seatsByRow;
  }

  public getSeat(seatId: string): SeatInfo | undefined {
    return this.props.seats.find(s => s.id === seatId);
  }

  public getSeatsInRow(row: string): SeatInfo[] {
    return this.props.seats.filter(s => s.row === row);
  }

  public getAccessibleSeats(): SeatInfo[] {
    return this.props.seats.filter(s => s.isAccessible === true);
  }

  public getPremiumSeats(): SeatInfo[] {
    return this.props.seats.filter(s => s.isPremium === true);
  }

  public getBoundingBox(): { minX: number; maxX: number; minY: number; maxY: number } {
    if (this.props.seats.length === 0) {
      return { minX: 0, maxX: 0, minY: 0, maxY: 0 };
    }

    const xCoords = this.props.seats.map(s => s.coordinates.x);
    const yCoords = this.props.seats.map(s => s.coordinates.y);

    return {
      minX: Math.min(...xCoords),
      maxX: Math.max(...xCoords),
      minY: Math.min(...yCoords),
      maxY: Math.max(...yCoords)
    };
  }
}
