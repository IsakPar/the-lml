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
    
    // Disable caching for seatmap requests to ensure fresh data
    if path.contains("/seatmap") {
      req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      req.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
      req.addValue("\(Date().timeIntervalSince1970)", forHTTPHeaderField: "X-Cache-Bust")
    }
    
    if let b = body {
      req.httpBody = b
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    if let key = idempotencyKey { req.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
    if let token = accessToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    if let org = orgId { 
      req.setValue(org, forHTTPHeaderField: "X-Org-ID")
      print("[ApiClient] Set X-Org-ID: \(org) for \(method) \(path)")
    } else {
      print("[ApiClient] WARNING: No orgId set for \(method) \(path)")
    }
    req.setValue("iOS", forHTTPHeaderField: "X-Client")
    headers?.forEach { k, v in 
      if k == "X-Org-ID" {
        // Skip X-Org-ID from headers since we already set it above
        print("[ApiClient] Skipping duplicate X-Org-ID from headers parameter")
      } else {
        req.addValue(v, forHTTPHeaderField: k)
      }
    }

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw ApiError.network("invalid response") }
    if http.statusCode >= 400 {
      if let prob = try? JSONDecoder().decode(ApiProblem.self, from: data) { throw ApiError.problem(prob) }
      throw ApiError.network("HTTP \(http.statusCode)")
    }
    return (data, http)
  }
}


