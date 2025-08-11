import Foundation
import CryptoKit

struct Jwk: Codable { let kty: String; let crv: String; let kid: String; let x: String }
struct Jwks: Codable { let keys: [Jwk] }

final class VerifierService {
  private var jwks: Jwks?
  private var jwksFetchedAt: Date?
  private let jwksTtlSeconds: TimeInterval = 300
  private let api: ApiClient
  init(api: ApiClient) { self.api = api }

  private func base64urlDecode(_ s: String) -> Data? {
    var str = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    let pad = (4 - (str.count % 4)) % 4
    if pad > 0 { str += String(repeating: "=", count: pad) }
    return Data(base64Encoded: str)
  }

  private func cryptoKeyFromJwkX(_ xB64u: String) -> Curve25519.Signing.PublicKey? {
    guard let x = base64urlDecode(xB64u) else { return nil }
    return try? Curve25519.Signing.PublicKey(rawRepresentation: x)
  }

  private func ensureJwksFresh() async throws {
    let now = Date()
    if let at = jwksFetchedAt, now.timeIntervalSince(at) < jwksTtlSeconds, jwks?.keys.isEmpty == false { return }
    let (data, _) = try await api.request(path: "/v1/verification/jwks", method: "GET")
    self.jwks = try JSONDecoder().decode(Jwks.self, from: data)
    self.jwksFetchedAt = Date()
  }

  func refreshJwks() async throws { try await ensureJwksFresh() }

  @discardableResult
  func verifyOffline(token: String, expectedTenant: String? = nil) throws -> Bool {
    let parts = token.split(separator: ".")
    guard parts.count == 5, parts[0] == "ed25519", parts[1] == "v1" else { throw NSError(domain: "token", code: 400) }
    let kid = String(parts[2]); let sig = String(parts[3]); let payload = String(parts[4])
    guard let jwk = jwks?.keys.first(where: { $0.kid == kid }) ?? jwks?.keys.first,
          let pub = cryptoKeyFromJwkX(jwk.x),
          let sigData = base64urlDecode(sig), let payloadData = base64urlDecode(payload) else { throw NSError(domain: "verify", code: 400) }
    guard pub.isValidSignature(sigData, for: payloadData) else { throw NSError(domain: "sig", code: 401) }
    if let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
      if let exp = obj["exp"] as? NSNumber { let now = Int(Date().timeIntervalSince1970); if now > exp.intValue + 60 { throw NSError(domain: "exp", code: 401) } }
      if let expected = expectedTenant, let ten = obj["tenant_id"] as? String, ten != expected { throw NSError(domain: "tenant", code: 409) }
    }
    return true
  }
}


