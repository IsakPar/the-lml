/**
 * Common types used across all bounded contexts
 */
// Common enums
export var BookingStatus;
(function (BookingStatus) {
    BookingStatus["PENDING"] = "pending";
    BookingStatus["PAYMENT_PROCESSING"] = "payment_processing";
    BookingStatus["CONFIRMED"] = "confirmed";
    BookingStatus["COMPLETED"] = "completed";
    BookingStatus["CANCELLED"] = "cancelled";
    BookingStatus["EXPIRED"] = "expired";
})(BookingStatus || (BookingStatus = {}));
export var PaymentStatus;
(function (PaymentStatus) {
    PaymentStatus["CREATED"] = "created";
    PaymentStatus["PROCESSING"] = "processing";
    PaymentStatus["SUCCEEDED"] = "succeeded";
    PaymentStatus["FAILED"] = "failed";
    PaymentStatus["CANCELLED"] = "cancelled";
})(PaymentStatus || (PaymentStatus = {}));
export var SeatStatus;
(function (SeatStatus) {
    SeatStatus["AVAILABLE"] = "available";
    SeatStatus["LOCKED"] = "locked";
    SeatStatus["RESERVED"] = "reserved";
    SeatStatus["SOLD"] = "sold";
})(SeatStatus || (SeatStatus = {}));
export var UserRole;
(function (UserRole) {
    UserRole["USER"] = "user";
    UserRole["ORGANIZER_ADMIN"] = "organizer_admin";
    UserRole["SUPPORT"] = "support";
    UserRole["SUPER_ADMIN"] = "super_admin";
})(UserRole || (UserRole = {}));
