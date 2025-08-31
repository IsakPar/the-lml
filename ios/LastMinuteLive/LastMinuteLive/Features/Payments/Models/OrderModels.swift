import Foundation

// MARK: - Order API Models

struct CreateOrderRequest: Codable {
    let performance_id: String
    let seat_ids: [String]
    let currency: String
    let total_minor: Int
    let customer_email: String
}

struct CreateOrderResponse: Codable {
    let order_id: String
    let client_secret: String
    let total_amount: Int
    let currency: String
    let customer_email: String? // ✅ Optional for robustness - backend now includes it
}

// MARK: - Order Details (GET /v1/orders/:id)
struct OrderDetailsResponse: Codable {
    let order_id: String
    let status: String
    let currency: String
    let total_minor: Int
    let tickets: [OrderTicket]?
}

struct OrderTicket: Codable {
    let id: String
    let seat_id: String
    let performance_id: String
    let jti: String
}
