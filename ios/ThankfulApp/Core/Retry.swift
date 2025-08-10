import Foundation

enum Retry {
  static func withBackoff<T>(maxAttempts: Int = 5, initialDelayMs: UInt64 = 100, factor: Double = 2.0, jitterMs: UInt64 = 50, _ op: @escaping () async throws -> T) async throws -> T {
    var attempt = 0
    var delay = initialDelayMs
    while true {
      do { return try await op() } catch {
        attempt += 1
        if attempt >= maxAttempts { throw error }
        let jitter = UInt64(Int64.random(in: -Int64(jitterMs)...Int64(jitterMs)))
        try? await Task.sleep(nanoseconds: (delay + jitter) * 1_000_000)
        delay = UInt64(Double(delay) * factor)
      }
    }
  }
}


