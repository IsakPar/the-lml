import Foundation

enum Config {
  static var apiBaseURL: URL { URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000")! }
  static var defaultOrgId: String { "00000000-0000-0000-0000-000000000001" }
}


