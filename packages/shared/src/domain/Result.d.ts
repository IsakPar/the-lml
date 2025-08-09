/**
 * Result pattern for handling success/failure scenarios
 * Avoids throwing exceptions in domain/application layers
 */
export declare class Result<T, E = Error> {
    private readonly _isSuccess;
    private readonly _value?;
    private readonly _error?;
    private constructor();
    static success<T, E = Error>(value?: T): Result<T, E>;
    static failure<T, E = Error>(error: E): Result<T, E>;
    get isSuccess(): boolean;
    get isFailure(): boolean;
    get value(): T;
    get error(): E;
    map<U>(fn: (value: T) => U): Result<U, E>;
    flatMap<U>(fn: (value: T) => Result<U, E>): Result<U, E>;
}
