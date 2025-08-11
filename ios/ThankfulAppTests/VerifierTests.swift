import XCTest
@testable import ThankfulApp

final class VerifierTests: XCTestCase {
  func testVerifyOfflineRejectsBadFormat() {
    let api = ApiClient(baseURL: URL(string: "https://example.invalid")!)
    let verifier = VerifierService(api: api)
    XCTAssertThrowsError(try verifier.verifyOffline(token: "bad.token"))
  }

  func testTicketsCacheRoundtrip() {
    let cache = TicketsCacheService()
    let org = "org_test"
    let ticket = CachedTicket(jti: "j1", token: "tkn", orderId: "ord1", performanceId: "p1", seatId: "A-1", tenantId: org, issuedAt: 0, expiresAt: nil)
    cache.upsert(orgId: org, ticket: ticket)
    let list = cache.list(orgId: org)
    XCTAssertTrue(list.contains(where: { $0.jti == "j1" }))
    cache.remove(orgId: org, jti: "j1")
    XCTAssertFalse(cache.list(orgId: org).contains(where: { $0.jti == "j1" }))
  }
}


