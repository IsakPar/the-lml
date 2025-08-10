import Foundation

final class OrderPollingService {
  private let orders: OrdersRepository
  init(orders: OrdersRepository) { self.orders = orders }
  func waitUntilPaid(orderId: String, timeoutSec: Int = 30) async -> Bool {
    let start = Date()
    while Date().timeIntervalSince(start) < Double(timeoutSec) {
      do {
        let o = try await orders.getOrder(id: orderId)
        if (o["status"] as? String) == "paid" { return true }
      } catch {}
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    return false
  }
}


