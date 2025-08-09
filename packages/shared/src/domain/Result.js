/**
 * Result pattern for handling success/failure scenarios
 * Avoids throwing exceptions in domain/application layers
 */
export class Result {
    _isSuccess;
    _value;
    _error;
    constructor(_isSuccess, _value, _error) {
        this._isSuccess = _isSuccess;
        this._value = _value;
        this._error = _error;
    }
    static success(value) {
        return new Result(true, value);
    }
    static failure(error) {
        return new Result(false, undefined, error);
    }
    get isSuccess() {
        return this._isSuccess;
    }
    get isFailure() {
        return !this._isSuccess;
    }
    get value() {
        if (!this._isSuccess) {
            throw new Error('Cannot get value from failed result');
        }
        return this._value;
    }
    get error() {
        if (this._isSuccess) {
            throw new Error('Cannot get error from successful result');
        }
        return this._error;
    }
    map(fn) {
        if (this._isSuccess) {
            return Result.success(fn(this._value));
        }
        return Result.failure(this._error);
    }
    flatMap(fn) {
        if (this._isSuccess) {
            return fn(this._value);
        }
        return Result.failure(this._error);
    }
}
