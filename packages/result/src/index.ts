export type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };
export const ok = <T, E = never>(value: T): Result<T, E> => ({ ok: true, value });
export const err = <T = never, E = unknown>(error: E): Result<T, E> => ({ ok: false, error });


