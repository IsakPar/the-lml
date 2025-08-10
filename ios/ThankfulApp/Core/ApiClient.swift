import Foundation

final class ApiClient {
  let baseURL: URL
  var accessToken: String?
  var orgId: String?

  init(baseURL: URL, accessToken: String? = nil, orgId: String? = nil) {
    self.baseURL = baseURL
    self.accessToken = accessToken
    self.orgId = orgId
  }

  func request(path: String, method: String = "GET", body: Data? = nil, idempotencyKey: String? = nil, headers: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
    var url = baseURL
    url.append(path: path)
    var req = URLRequest(url: url)
    req.httpMethod = method
    if let b = body {
      req.httpBody = b
      req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    if let key = idempotencyKey { req.addValue(key, forHTTPHeaderField: "Idempotency-Key") }
    if let token = accessToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    if let org = orgId { req.addValue(org, forHTTPHeaderField: "X-Org-ID") }
    req.addValue("iOS", forHTTPHeaderField: "X-Client")
    headers?.forEach { k, v in req.addValue(v, forHTTPHeaderField: k) }

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw ApiError.network("invalid response") }
    if http.statusCode >= 400 {
      if let prob = try? JSONDecoder().decode(ApiProblem.self, from: data) { throw ApiError.problem(prob) }
      throw ApiError.network("HTTP \(http.statusCode)")
    }
    return (data, http)
  }
}


