import Foundation

protocol OrdersRepository {
  func createOrder(totalMinor: Int, currency: String) async throws -> String
  func getOrder(id: String) async throws -> [String: Any]
}

final class OrdersRepositoryLive: OrdersRepository {
  private let client: ApiClient
  init(client: ApiClient) { self.client = client }
  func createOrder(totalMinor: Int, currency: String) async throws -> String {
    let body = try JSONSerialization.data(withJSONObject: ["total_minor": totalMinor, "currency": currency])
    let key = Idempotency.key(method: "POST", path: "/v1/orders", body: body)
    let (data, _) = try await client.request(path: "/v1/orders", method: "POST", body: body, idempotencyKey: key)
    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return obj?["order_id"] as? String ?? ""
  }
  func getOrder(id: String) async throws -> [String: Any] {
    let (data, _) = try await client.request(path: "/v1/orders/\(id)")
    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return obj ?? [:]
  }
}

protocol PaymentsRepository {
  func createPaymentIntent(orderId: String, amountMinor: Int, currency: String) async throws -> [String: Any]
}

final class PaymentsRepositoryLive: PaymentsRepository {
  private let client: ApiClient
  init(client: ApiClient) { self.client = client }
  func createPaymentIntent(orderId: String, amountMinor: Int, currency: String) async throws -> [String: Any] {
    let body = try JSONSerialization.data(withJSONObject: ["order_id": orderId, "amount_minor": amountMinor, "currency": currency])
    let key = Idempotency.key(method: "POST", path: "/v1/payments/intents", body: body)
    let (data, _) = try await client.request(path: "/v1/payments/intents", method: "POST", body: body, idempotencyKey: key)
    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return obj ?? [:]
  }
}


