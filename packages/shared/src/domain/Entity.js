/**
 * Base Entity class for DDD entities
 * All domain entities should extend this class
 */
export class Entity {
    _id;
    constructor(_id) {
        this._id = _id;
    }
    get id() {
        return this._id;
    }
    equals(other) {
        if (!other) {
            return false;
        }
        if (this === other) {
            return true;
        }
        return this._id === other._id;
    }
}
