import Foundation
import Stripe
import StripePaymentSheet
import PassKit

// MARK: - Real Stripe Payment Processor with Official PaymentSheet

@MainActor
class StripePaymentProcessor: ObservableObject {
  
  // MARK: - Properties
  
  @Published var paymentState: PaymentState = .idle
  @Published var errorMessage: String?
  
  private var clientSecret: String?
  private var paymentSheet: PaymentSheet?
  private var isConfigured = false
  
  // MARK: - Configuration
  
  func configure(with clientSecret: String) {
    self.clientSecret = clientSecret
    
    // Configure Stripe API
    StripeAPI.defaultPublishableKey = Config.stripePublishableKey
    
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
    
    // Create the official Stripe PaymentSheet
    self.paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
    isConfigured = true
  }
  
  // MARK: - Present Official Stripe PaymentSheet
  
  func presentPaymentOptions() async -> PaymentResult {
    guard let paymentSheet = paymentSheet, isConfigured else {
      await MainActor.run {
        errorMessage = "PaymentSheet not configured"
        paymentState = .completed(.failed)
      }
      return .failed
    }
    
    await MainActor.run {
      paymentState = .processing
      errorMessage = nil
    }
    
    return await withCheckedContinuation { continuation in
      // Find the presenting view controller
      guard let presentingViewController = getRootViewController() else {
        Task { @MainActor in
          self.errorMessage = "Cannot find presenting view controller"
          self.paymentState = .completed(.failed)
        }
        continuation.resume(returning: .failed)
        return
      }
      
      // Present the official Stripe PaymentSheet
      paymentSheet.present(from: presentingViewController) { [weak self] paymentResult in
        Task { @MainActor in
          guard let self = self else { return }
          
          let result: PaymentResult
          
          switch paymentResult {
          case .completed:
            result = .success
            self.paymentState = .completed(.success)
            
          case .canceled:
            result = .cancelled
            self.paymentState = .completed(.cancelled)
            
          case .failed(let error):
            result = .failed
            self.errorMessage = error.localizedDescription
            self.paymentState = .completed(.failed)
          }
          
          continuation.resume(returning: result)
        }
      }
    }
  }
  
  // MARK: - Reset State
  
  func resetState() {
    paymentState = .idle
    errorMessage = nil
    paymentSheet = nil
    clientSecret = nil
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