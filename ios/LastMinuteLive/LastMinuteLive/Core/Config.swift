import Foundation

enum Config {
  static var apiBaseURL: URL { URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000")! }
  static var defaultOrgId: String { "00000000-0000-0000-0000-000000000001" }
  static let merchantIdentifier: String = (ProcessInfo.processInfo.environment["APPLE_MERCHANT_ID"]) ?? "merchant.com.thankful.dev"
  static let countryCode: String = "GB"
  static let currencyCode: String = "GBP"
  // Stripe Configuration
  static let stripePublishableKey: String = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"] ?? "pk_test_..."  // Add your Stripe publishable key
}


