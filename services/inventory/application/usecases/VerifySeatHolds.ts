export interface VerifySeatHoldsCommand {
  tenantId: string;
  performanceId: string;
  seatIds: string[];
  holdToken: string; // version:owner
}

export type VerifySeatHoldsResult = { ok: true } | { ok: false; conflicts: string[] } | { ok: false; reason: 'invalid_token' };

export interface SeatHoldReaderPort {
  getHold(tenantId: string, performanceId: string, seatId: string): Promise<{ version: number; owner: string } | null>;
}

export class VerifySeatHoldsUseCase {
  constructor(private reader: SeatHoldReaderPort) {}

  async execute(cmd: VerifySeatHoldsCommand): Promise<VerifySeatHoldsResult> {
    if (!cmd.holdToken || !cmd.holdToken.includes(':')) return { ok: false, reason: 'invalid_token' };
    const [vStr, owner] = cmd.holdToken.split(':');
    const vNum = Number(vStr);
    if (!Number.isFinite(vNum) || !owner) return { ok: false, reason: 'invalid_token' };
    const conflicts: string[] = [];
    for (const seatId of cmd.seatIds) {
      const hold = await this.reader.getHold(cmd.tenantId, cmd.performanceId, seatId);
      if (!hold || hold.owner !== owner || !Number.isFinite(hold.version)) conflicts.push(seatId);
    }
    return conflicts.length === 0 ? { ok: true } : { ok: false, conflicts };
  }
}


