/**
 * Base ValueObject class for DDD value objects
 * Value objects are immutable and compared by value equality
 */
export abstract class ValueObject<T> {
  protected constructor(protected readonly props: T) {}

  public equals(other?: ValueObject<T>): boolean {
    if (!other) {
      return false;
    }

    if (this === other) {
      return true;
    }

    return JSON.stringify(this.props) === JSON.stringify(other.props);
  }

  public getValue(): T {
    return this.props;
  }
}
