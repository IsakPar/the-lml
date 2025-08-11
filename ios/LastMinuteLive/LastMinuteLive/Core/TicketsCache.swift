import Foundation

struct CachedTicket: Codable, Equatable, Identifiable {
  var id: String { jti }
  let jti: String
  let token: String
  let orderId: String
  let performanceId: String
  let seatId: String
  let tenantId: String
  let issuedAt: Int
  let expiresAt: Int?
}

final class TicketsCacheService {
  private let keyPrefix = "tickets_cache_"
  private func key(orgId: String) -> String { keyPrefix + orgId }

  func list(orgId: String) -> [CachedTicket] {
    guard let data = KeychainHelper.load(key: key(orgId: orgId)) else { return [] }
    return (try? JSONDecoder().decode([CachedTicket].self, from: data)) ?? []
  }

  func save(orgId: String, tickets: [CachedTicket]) { if let data = try? JSONEncoder().encode(tickets) { _ = KeychainHelper.save(key: key(orgId: orgId), data: data) } }

  func upsert(orgId: String, ticket: CachedTicket) {
    var arr = list(orgId: orgId)
    if let idx = arr.firstIndex(where: { $0.jti == ticket.jti }) { arr[idx] = ticket } else { arr.append(ticket) }
    save(orgId: orgId, tickets: arr)
  }

  func remove(orgId: String, jti: String) {
    var arr = list(orgId: orgId)
    arr.removeAll { $0.jti == jti }
    save(orgId: orgId, tickets: arr)
  }
}


