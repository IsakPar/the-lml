import Foundation
import SwiftUI

final class AppState: ObservableObject {
  @Published var isAuthenticated: Bool = false
  @Published var userEmail: String? = nil
  @Published var accessToken: String? = nil {
    didSet {
      // Sync the access token with the ApiClient
      api.accessToken = accessToken
      print("[Auth] Updated access token, orgId remains: \(api.orgId ?? "nil")")
    }
  }
  let api = ApiClient(baseURL: Config.apiBaseURL, orgId: Config.defaultOrgId)
  lazy var verifier = VerifierService(api: api)
  let ticketsCache = TicketsCacheService()
  
  init() {
    // Ensure orgId is set from the start
    api.orgId = Config.defaultOrgId
    print("[AppState] Initialized with orgId: \(Config.defaultOrgId)")
  }

  func verifierStartRefresh() {
    Task { try? await verifier.refreshJwks() }
  }
  
  @MainActor
  func authenticateForDevelopment() async {
    guard accessToken == nil else { return } // Already authenticated
    
    do {
      print("[Auth] Attempting development authentication...")
      let payload = [
        "grant_type": "client_credentials",
        "client_id": "test_client",
        "client_secret": "test_secret"
      ]
      
      let data = try JSONSerialization.data(withJSONObject: payload)
      let (responseData, _) = try await api.request(
        path: "/v1/oauth/token",
        method: "POST", 
        body: data
      )
      
      let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
      
      if let token = response?["access_token"] as? String {
        self.accessToken = token
        self.isAuthenticated = true
        // Set development email for testing
        self.userEmail = "dev@lastminutelive.com"
        print("[Auth] Development authentication successful with email: \(self.userEmail ?? "nil")")
      } else {
        print("[Auth] Development authentication failed - no token in response")
      }
      
    } catch {
      print("[Auth] Development authentication error: \(error)")
    }
  }

  func cacheTicketFromToken(orgId: String, token: String) {
    // Parse payload from ed25519.v1.kid.sig.payload
    let parts = token.split(separator: ".")
    guard parts.count == 5 else { return }
    let payloadB64 = String(parts[4])
    func b64u(_ s: String) -> Data? {
      var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
      let pad = (4 - (t.count % 4)) % 4
      if pad > 0 { t += String(repeating: "=", count: pad) }
      return Data(base64Encoded: t)
    }
    guard let data = b64u(payloadB64),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    let jti = (obj["jti"] as? String) ?? ""
    let perf = (obj["performance_id"] as? String) ?? ""
    let seat = (obj["seat_id"] as? String) ?? ""
    let ord  = (obj["order_id"] as? String) ?? ""
    let ten  = (obj["tenant_id"] as? String) ?? orgId
    let iat  = (obj["iat"] as? NSNumber)?.intValue ?? 0
    let exp  = (obj["exp"] as? NSNumber)?.intValue
    guard !jti.isEmpty else { return }
    let ct = CachedTicket(jti: jti, token: token, orderId: ord, performanceId: perf, seatId: seat, tenantId: ten, issuedAt: iat, expiresAt: exp)
    ticketsCache.upsert(orgId: orgId, ticket: ct)
  }

  @MainActor
  func issueAndCacheTicket(orderId: String, performanceId: String, seatId: String) async {
    do {
      let body: [String: Any] = ["order_id": orderId, "performance_id": performanceId, "seat_id": seatId]
      let data = try JSONSerialization.data(withJSONObject: body)
      let (resp, _) = try await api.request(path: "/v1/tickets/issue", method: "POST", body: data)
      if let obj = try JSONSerialization.jsonObject(with: resp) as? [String: Any], let token = obj["ticket_token"] as? String {
        cacheTicketFromToken(orgId: Config.defaultOrgId, token: token)
      }
    } catch {
      print("Failed to issue/cache ticket: \(error)")
    }
  }
}


