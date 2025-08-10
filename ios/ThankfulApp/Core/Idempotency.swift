import Foundation
import CryptoKit

enum Idempotency {
  static func key(method: String, path: String, body: Data?) -> String {
    var concat = method + " " + path
    if let b = body { concat += " " + (String(data: b, encoding: .utf8) ?? "") }
    let digest = SHA256.hash(data: Data(concat.utf8))
    let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
    return "idem-" + hex.prefix(24)
  }
}


