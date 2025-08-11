import Foundation
import Security

struct Jwk: Codable { let kty: String; let crv: String; let kid: String; let x: String }
struct Jwks: Codable { let keys: [Jwk] }

final class VerifierService {
  private var jwks: Jwks?
  private var jwksFetchedAt: Date?
  private let jwksTtlSeconds: TimeInterval = 300
  private let skewSeconds: Int = 60
  private var timer: Timer?
  private let api: ApiClient
  private let cache = TicketsCacheService()
  init(api: ApiClient) { self.api = api }

  private func base64urlDecode(_ s: String) -> Data? {
    var str = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    let pad = 4 - (str.count % 4)
    if pad < 4 { str += String(repeating: "=", count: pad) }
    return Data(base64Encoded: str)
  }

  private func ed25519Spki(from raw: Data) -> Data {
    // DER: SEQUENCE { SEQUENCE { OID 1.3.101.112 }, BIT STRING (raw pubkey) }
    var bytes = [UInt8]()
    bytes += [0x30, 0x2A]               // SEQ, len 42
    bytes += [0x30, 0x05]               // SEQ, len 5
    bytes += [0x06, 0x03, 0x2B, 0x65, 0x70] // OID 1.3.101.112
    bytes += [0x03, 0x21, 0x00]         // BIT STRING, len 33, 0 unused bits
    bytes += raw
    return Data(bytes)
  }

  private func secKeyFromJwkX(_ xB64u: String) -> SecKey? {
    guard let x = base64urlDecode(xB64u) else { return nil }
    let spki = ed25519Spki(from: x)
    let attrs: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeEd25519,
      kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
      kSecAttrKeySizeInBits as String: 256
    ]
    var err: Unmanaged<CFError>?
    return SecKeyCreateWithData(spki as CFData, attrs as CFDictionary, &err)
  }

  private func ensureJwksFresh() async throws {
    let now = Date()
    if let at = jwksFetchedAt, now.timeIntervalSince(at) < jwksTtlSeconds, jwks?.keys.isEmpty == false { return }
    let req = try await api.request(path: "/v1/verification/jwks", method: "GET")
    let (data, _) = try await URLSession.shared.data(for: req)
    self.jwks = try JSONDecoder().decode(Jwks.self, from: data)
    self.jwksFetchedAt = Date()
  }

  func refreshJwks() async throws { try await ensureJwksFresh() }

  // Testing helper to inject JWKS without network
  func injectJwksForTesting(_ jwks: Jwks) { self.jwks = jwks; self.jwksFetchedAt = Date() }

  func startAutoRefresh() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: jwksTtlSeconds, repeats: true) { [weak self] _ in
      Task { try? await self?.ensureJwksFresh() }
    }
  }

  func stopAutoRefresh() { timer?.invalidate(); timer = nil }

  func redeem(token: String, orgId: String) async throws -> (String, String) {
    let body: [String: Any] = ["ticket_token": token]
    let bodyData = try JSONSerialization.data(withJSONObject: body)
    let (data, _) = try await api.request(path: "/v1/verification/redeem", method: "POST", body: bodyData, headers: nil)
    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let jti = obj?["jti"] as? String ?? ""
    let status = obj?["status"] as? String ?? ""
    if status == "redeemed" { cache.remove(orgId: orgId, jti: jti) }
    return (jti, status)
  }

  @discardableResult
  func verifyOffline(token: String, expectedTenant: String? = nil) throws -> Bool {
    // Token: ed25519.v1.kid.sig.payload
    let parts = token.split(separator: ".")
    guard parts.count == 5, parts[0] == "ed25519", parts[1] == "v1" else {
      throw Problem(type: "urn:thankful:verification:bad_format", title: "invalid_token", status: 400, detail: "bad token format")
    }
    let kid = String(parts[2])
    guard let sig = base64urlDecode(String(parts[3])), let payloadData = base64urlDecode(String(parts[4])) else {
      throw Problem(type: "urn:thankful:verification:bad_parts", title: "invalid_token", status: 400, detail: "bad token parts")
    }
    guard let jwk = jwks?.keys.first(where: { $0.kid == kid }) ?? jwks?.keys.first else {
      throw Problem(type: "urn:thankful:verification:no_key", title: "no_key", status: 400, detail: "missing key")
    }
    guard let pub = secKeyFromJwkX(jwk.x) else {
      throw Problem(type: "urn:thankful:verification:key_error", title: "key_error", status: 400, detail: "invalid key")
    }
    var err: Unmanaged<CFError>?
    let ok = SecKeyVerifySignature(pub, .ed25519, payloadData as CFData, sig as CFData, &err)
    if !ok { throw Problem(type: "urn:thankful:verification:invalid_signature", title: "invalid_signature", status: 401, detail: "sig mismatch") }
    // exp/tenant checks (best-effort)
    if let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
      if let exp = obj["exp"] as? NSNumber {
        let nowSec = Int(Date().timeIntervalSince1970)
        if nowSec > exp.intValue + skewSeconds { throw Problem(type: "urn:thankful:verification:expired", title: "expired_ticket", status: 401, detail: "expired") }
      }
      if let expected = expectedTenant, let tenant = obj["tenant_id"] as? String, tenant != expected {
        throw Problem(type: "urn:thankful:verification:tenant_mismatch", title: "tenant_mismatch", status: 409, detail: "tenant mismatch")
      }
    }
    return true
  }

  func cacheTicketFromToken(orgId: String, token: String) {
    let parts = token.split(separator: ".")
    guard parts.count == 5 else { return }
    guard let payload = base64urlDecode(String(parts[4])) else { return }
    guard let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return }
    let jti = (obj["jti"] as? String) ?? ""
    let perf = (obj["performance_id"] as? String) ?? ""
    let seat = (obj["seat_id"] as? String) ?? ""
    let ord = (obj["order_id"] as? String) ?? ""
    let ten = (obj["tenant_id"] as? String) ?? ""
    let iat = (obj["iat"] as? NSNumber)?.intValue ?? 0
    let exp = (obj["exp"] as? NSNumber)?.intValue
    if !jti.isEmpty {
      let c = CachedTicket(jti: jti, token: token, orderId: ord, performanceId: perf, seatId: seat, tenantId: ten, issuedAt: iat, expiresAt: exp)
      cache.upsert(orgId: orgId, ticket: c)
    }
  }
}


