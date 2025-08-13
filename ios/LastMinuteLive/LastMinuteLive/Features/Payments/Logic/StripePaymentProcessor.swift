import Foundation
import Stripe
import PassKit

// MARK: - Simplified Stripe Payment Processor

@MainActor
class StripePaymentProcessor: ObservableObject {
  
  // MARK: - Properties
  
  @Published var paymentState: PaymentState = .idle
  @Published var errorMessage: String?
  
  private var paymentSheet: PaymentSheet?
  private var isConfigured = false
  
  // MARK: - Configuration
  
  func configure(with clientSecret: String, customerId: String? = nil) {
    // Configure Stripe API
    STPAPIClient.shared.publishableKey = Config.stripePublishableKey
    
    // Create PaymentSheet configuration
    var configuration = PaymentSheet.Configuration()
    configuration.merchantDisplayName = "LastMinuteLive"
    configuration.allowsDelayedPaymentMethods = false
    
    // Add Apple Pay configuration if available
    if PKPaymentAuthorizationViewController.canMakePayments() {
      configuration.applePay = .init(
        merchantId: Config.merchantIdentifier,
        merchantCountryCode: Config.countryCode
      )
    }
    
    // Create PaymentSheet
    paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
    isConfigured = true
  }
  
  // MARK: - Present PaymentSheet
  
  func presentPaymentSheet() -> PaymentResult? {
    guard let paymentSheet = paymentSheet else {
      errorMessage = "Payment sheet not configured"
      return .failed
    }
    
    // Find the presenting view controller
    guard let presentingViewController = getRootViewController() else {
      errorMessage = "Cannot find presenting view controller"
      return .failed
    }
    
    paymentState = .processing
    errorMessage = nil
    
    var result: PaymentResult?
    
    paymentSheet.present(from: presentingViewController) { [weak self] paymentResult in
      DispatchQueue.main.async {
        switch paymentResult {
        case .completed:
          result = .success
          self?.paymentState = .completed(.success)
        case .canceled:
          result = .cancelled
          self?.paymentState = .completed(.cancelled)
        case .failed(let error):
          result = .failed
          self?.errorMessage = error.localizedDescription
          self?.paymentState = .completed(.failed)
        }
      }
    }
    
    return result
  }
  
  // MARK: - Reset State
  
  func resetState() {
    paymentState = .idle
    errorMessage = nil
    paymentSheet = nil
    isConfigured = false
  }
  
  // MARK: - Helper Methods
  
  private func getRootViewController() -> UIViewController? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  }
}