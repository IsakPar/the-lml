/**
 * Base Entity class for DDD entities
 * All domain entities should extend this class
 */
export abstract class Entity<TId> {
  protected constructor(protected readonly _id: TId) {}

  public get id(): TId {
    return this._id;
  }

  public equals(other?: Entity<TId>): boolean {
    if (!other) {
      return false;
    }

    if (this === other) {
      return true;
    }

    return this._id === other._id;
  }
}
