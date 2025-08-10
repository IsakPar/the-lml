import Foundation

struct ApiProblem: Codable, Error {
  let type: String
  let title: String
  let status: Int
  let detail: String?
  let instance: String?
  let trace_id: String?
}

enum ApiError: Error, LocalizedError {
  case network(String)
  case problem(ApiProblem)
  case decoding(String)

  var errorDescription: String? {
    switch self {
    case .network(let m): return m
    case .decoding(let m): return m
    case .problem(let p): return "\(p.title) (\(p.status))\n\(p.detail ?? "")"
    }
  }
}


