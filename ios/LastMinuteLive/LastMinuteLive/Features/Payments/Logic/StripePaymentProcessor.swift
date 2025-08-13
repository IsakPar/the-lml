import Foundation
import Stripe
import PassKit

// MARK: - Simplified Stripe Payment Processor

@MainActor
class StripePaymentProcessor: ObservableObject {
  
  // MARK: - Properties
  
  @Published var paymentState: PaymentState = .idle
  @Published var errorMessage: String?
  
  private var clientSecret: String?
  private var isConfigured = false
  
  // MARK: - Configuration
  
  func configure(with clientSecret: String) {
    // Configure Stripe API
    STPAPIClient.shared.publishableKey = Config.stripePublishableKey
    
    self.clientSecret = clientSecret
    isConfigured = true
  }
  
  // MARK: - Present Payment Options
  
  func presentPaymentOptions() async -> PaymentResult {
    guard let clientSecret = clientSecret, isConfigured else {
      await MainActor.run {
        errorMessage = "Payment not configured"
        paymentState = .completed(.failed)
      }
      return .failed
    }
    
    await MainActor.run {
      paymentState = .processing
      errorMessage = nil
    }
    
    // Try to use native PaymentSheet first, fallback to manual implementation
    if let result = await presentNativePaymentSheet(clientSecret: clientSecret) {
      return result
    } else {
      return await presentManualPayment(clientSecret: clientSecret)
    }
  }
  
  // MARK: - Native PaymentSheet (if available)
  
  private func presentNativePaymentSheet(clientSecret: String) async -> PaymentResult? {
    // This will only work if StripePaymentSheet is available
    // We'll implement a check for this
    return nil // Fallback to manual for now
  }
  
  // MARK: - Manual Payment Implementation
  
  private func presentManualPayment(clientSecret: String) async -> PaymentResult {
    return await withCheckedContinuation { continuation in
      // Create a simple payment intent confirmation
      let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
      
      // For now, we'll create a basic card payment setup
      // This can be expanded to show a native card input form
      
      // Get the authentication context
      guard let authContext = getAuthenticationContext() else {
        continuation.resume(returning: .failed)
        return
      }
      
      // Use STPPaymentHandler to confirm payment
      let paymentHandler = STPPaymentHandler.shared()
      
      paymentHandler.confirmPayment(paymentIntentParams, with: authContext) { status, paymentIntent, error in
        DispatchQueue.main.async {
          switch status {
          case .succeeded:
            self.paymentState = .completed(.success)
            continuation.resume(returning: .success)
          case .canceled:
            self.paymentState = .completed(.cancelled)
            continuation.resume(returning: .cancelled)
          case .failed:
            self.errorMessage = error?.localizedDescription ?? "Payment failed"
            self.paymentState = .completed(.failed)
            continuation.resume(returning: .failed)
          @unknown default:
            self.errorMessage = "Unknown payment status"
            self.paymentState = .completed(.failed)
            continuation.resume(returning: .failed)
          }
        }
      }
    }
  }
  
  // MARK: - Reset State
  
  func resetState() {
    paymentState = .idle
    errorMessage = nil
    clientSecret = nil
    isConfigured = false
  }
  
  // MARK: - Helper Methods
  
  private func getAuthenticationContext() -> STPAuthenticationContext? {
    guard let rootViewController = getRootViewController() else {
      return nil
    }
    
    return AuthenticationContextWrapper(viewController: rootViewController)
  }
  
  private func getRootViewController() -> UIViewController? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  }
}

// MARK: - Authentication Context Wrapper

private class AuthenticationContextWrapper: NSObject, STPAuthenticationContext {
  private weak var viewController: UIViewController?
  
  init(viewController: UIViewController) {
    self.viewController = viewController
  }
  
  func authenticationPresentingViewController() -> UIViewController {
    return viewController ?? UIViewController()
  }
}