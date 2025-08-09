/**
 * Base ValueObject class for DDD value objects
 * Value objects are immutable and compared by value equality
 */
export declare abstract class ValueObject<T> {
    protected readonly props: T;
    protected constructor(props: T);
    equals(other?: ValueObject<T>): boolean;
    getValue(): T;
}
