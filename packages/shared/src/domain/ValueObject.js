/**
 * Base ValueObject class for DDD value objects
 * Value objects are immutable and compared by value equality
 */
export class ValueObject {
    props;
    constructor(props) {
        this.props = props;
    }
    equals(other) {
        if (!other) {
            return false;
        }
        if (this === other) {
            return true;
        }
        return JSON.stringify(this.props) === JSON.stringify(other.props);
    }
    getValue() {
        return this.props;
    }
}
