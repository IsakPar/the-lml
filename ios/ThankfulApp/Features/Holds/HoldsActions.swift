import Foundation

struct HoldRequest: Codable { let performance_id: String; let seats: [String]; let ttl_seconds: Int }

enum HoldsApi {
  static func acquire(client: ApiClient, perfId: String, seats: [String], ttl: Int) async throws -> [String: Any] {
    let body = try JSONEncoder().encode(HoldRequest(performance_id: perfId, seats: seats, ttl_seconds: ttl))
    let key = Idempotency.key(method: "POST", path: "/v1/holds", body: body)
    let (data, _) = try await client.request(path: "/v1/holds", method: "POST", body: body, idempotencyKey: key)
    guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
    return obj
  }

  static func extend(client: ApiClient, perfId: String, seatId: String, addSec: Int, holdToken: String) async throws -> [String: Any] {
    let payload: [String: Any] = ["performance_id": perfId, "seat_id": seatId, "additional_seconds": addSec, "hold_token": holdToken]
    let data = try JSONSerialization.data(withJSONObject: payload)
    let key = Idempotency.key(method: "PATCH", path: "/v1/holds", body: data)
    let (resp, _) = try await client.request(path: "/v1/holds", method: "PATCH", body: data, idempotencyKey: key, headers: ["If-Match": holdToken])
    guard let obj = try JSONSerialization.jsonObject(with: resp) as? [String: Any] else { return [:] }
    return obj
  }

  static func release(client: ApiClient, holdId: String, perfId: String, seatId: String, holdToken: String) async throws {
    let key = Idempotency.key(method: "DELETE", path: "/v1/holds/\(holdId)", body: nil)
    _ = try await client.request(path: "/v1/holds/\(holdId)?performance_id=\(perfId)&seat_id=\(seatId)", method: "DELETE", idempotencyKey: key, headers: ["If-Match": holdToken])
  }
}


