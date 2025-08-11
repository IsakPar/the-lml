import Foundation

struct ApiProblem: Codable, Error { let type: String; let title: String; let status: Int; let detail: String? }

enum ApiError: Error, LocalizedError {
  case network(String)
  case problem(ApiProblem)
  var errorDescription: String? {
    switch self {
    case .network(let s): return s
    case .problem(let p): return p.detail ?? p.title
    }
  }
}


