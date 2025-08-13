import Foundation
import Stripe
import PassKit

// MARK: - Payment Processing Errors

enum PaymentProcessingError: LocalizedError {
  case invalidConfiguration
  case invalidCardData
  case stripeNotConfigured
  case applePayNotAvailable
  case processingFailed(String)
  
  var errorDescription: String? {
    switch self {
    case .invalidConfiguration:
      return "Payment configuration is invalid"
    case .invalidCardData:
      return "Card information is invalid"
    case .stripeNotConfigured:
      return "Stripe is not properly configured"
    case .applePayNotAvailable:
      return "Apple Pay is not available on this device"
    case .processingFailed(let message):
      return "Payment processing failed: \(message)"
    }
  }
}

// MARK: - Stripe Payment Processor

@MainActor
class StripePaymentProcessor: ObservableObject {
  
  // MARK: - Properties
  
  @Published var paymentState: PaymentState = .idle
  @Published var errorMessage: String?
  
  private var configuration: PaymentConfiguration?
  private var isConfigured = false
  
  // MARK: - Configuration
  
  func configure(with config: PaymentConfiguration) {
    self.configuration = config
    STPAPIClient.shared.publishableKey = config.stripePublishableKey
    isConfigured = true
  }
  
  // MARK: - Apple Pay Support
  
  var isApplePaySupported: Bool {
    return PKPaymentAuthorizationViewController.canMakePayments()
  }
  
  // MARK: - Card Payment Processing
  
  func processCardPayment(with formData: PaymentFormData) async throws -> PaymentResult {
    guard let config = configuration, isConfigured else {
      throw PaymentProcessingError.stripeNotConfigured
    }
    
    // Update state
    paymentState = .processing
    errorMessage = nil
    
    do {
      // Create payment method parameters
      let paymentMethodParams = try createPaymentMethodParams(from: formData)
      
      // Create payment intent parameters
      let paymentIntentParams = STPPaymentIntentParams(clientSecret: config.clientSecret)
      paymentIntentParams.paymentMethodParams = paymentMethodParams
      
      // Process payment with Stripe
      let result = try await confirmPaymentIntent(paymentIntentParams)
      
      // Update state based on result
      paymentState = .completed(result)
      
      return result
      
    } catch {
      let failureResult = PaymentResult.failed
      paymentState = .completed(failureResult)
      errorMessage = error.localizedDescription
      throw error
    }
  }
  
  // MARK: - Apple Pay Processing
  
  func processApplePayPayment() async throws -> PaymentResult {
    guard let config = configuration, isConfigured else {
      throw PaymentProcessingError.stripeNotConfigured
    }
    
    guard isApplePaySupported else {
      throw PaymentProcessingError.applePayNotAvailable
    }
    
    // Update state
    paymentState = .processing
    errorMessage = nil
    
    do {
      // Create Apple Pay request
      let paymentRequest = createApplePayRequest(for: config.orderSummary)
      
      // Process Apple Pay
      let result = try await processApplePayRequest(paymentRequest, clientSecret: config.clientSecret)
      
      // Update state
      paymentState = .completed(result)
      
      return result
      
    } catch {
      let failureResult = PaymentResult.failed
      paymentState = .completed(failureResult)
      errorMessage = error.localizedDescription
      throw error
    }
  }
  
  // MARK: - Reset State
  
  func resetState() {
    paymentState = .idle
    errorMessage = nil
  }
  
  // MARK: - Private Methods
  
  private func createPaymentMethodParams(from formData: PaymentFormData) throws -> STPPaymentMethodParams {
    // Validate form data
    let validationResult = CardInputValidation.validatePaymentForm(
      cardNumber: formData.cardNumber,
      expiryDate: formData.expiryDate,
      cvc: formData.cvcCode,
      email: formData.email,
      nameOnCard: formData.nameOnCard
    )
    
    guard validationResult.isValid else {
      throw PaymentProcessingError.invalidCardData
    }
    
    // Create card parameters
    let cardParams = STPPaymentMethodCardParams()
    cardParams.number = formData.cleanCardNumber
    cardParams.cvc = formData.formattedCVC
    
    // Parse expiry date
    let expiryComponents = formData.formattedExpiry.split(separator: "/")
    if expiryComponents.count == 2,
       let month = Int(expiryComponents[0]),
       let year = Int(expiryComponents[1]) {
      cardParams.expMonth = NSNumber(value: month)
      cardParams.expYear = NSNumber(value: year < 50 ? 2000 + year : 1900 + year)
    }
    
    // Create billing details
    let billingDetails = STPPaymentMethodBillingDetails()
    billingDetails.email = formData.email
    billingDetails.name = formData.formattedName
    
    // Create payment method parameters
    return STPPaymentMethodParams(card: cardParams, billingDetails: billingDetails, metadata: nil)
  }
  
  private func confirmPaymentIntent(_ params: STPPaymentIntentParams) async throws -> PaymentResult {
    return try await withCheckedThrowingContinuation { continuation in
      let paymentHandler = STPPaymentHandler.shared()
      
      // Use the current view controller as authentication context
      guard let authContext = getAuthenticationContext() else {
        continuation.resume(throwing: PaymentProcessingError.processingFailed("Cannot find authentication context"))
        return
      }
      
      paymentHandler.confirmPayment(params, with: authContext) { status, paymentIntent, error in
        switch status {
        case .succeeded:
          continuation.resume(returning: .success)
        case .canceled:
          continuation.resume(returning: .cancelled)
        case .failed:
          let errorMessage = error?.localizedDescription ?? "Payment failed"
          continuation.resume(throwing: PaymentProcessingError.processingFailed(errorMessage))
        @unknown default:
          continuation.resume(throwing: PaymentProcessingError.processingFailed("Unknown payment status"))
        }
      }
    }
  }
  
  private func createApplePayRequest(for orderSummary: OrderSummary) -> PKPaymentRequest {
    guard let config = configuration else {
      fatalError("Configuration not set")
    }
    
    let request = PKPaymentRequest()
    request.merchantIdentifier = config.appleMerchantIdentifier ?? "merchant.com.thankful.dev"
    request.countryCode = "GB"
    request.currencyCode = orderSummary.currency
    request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
    request.merchantCapabilities = .capability3DS
    
    request.paymentSummaryItems = [
      PKPaymentSummaryItem(
        label: "Tickets (\(orderSummary.seatDescription))",
        amount: NSDecimalNumber(value: Double(orderSummary.totalAmount) / 100)
      )
    ]
    
    return request
  }
  
  private func processApplePayRequest(_ request: PKPaymentRequest, clientSecret: String) async throws -> PaymentResult {
    return try await withCheckedThrowingContinuation { continuation in
      // Create Apple Pay context with delegate
      let applePayContext = STPApplePayContext(paymentRequest: request, delegate: ApplePayDelegate { result in
        continuation.resume(returning: result)
      })
      
      guard let context = applePayContext else {
        continuation.resume(throwing: PaymentProcessingError.applePayNotAvailable)
        return
      }
      
      // Present Apple Pay sheet
      context.presentApplePay()
    }
  }
  
  private func getAuthenticationContext() -> STPAuthenticationContext? {
    // Get root view controller that conforms to STPAuthenticationContext
    guard let rootViewController = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController else {
      return nil
    }
    
    return AuthenticationContextWrapper(viewController: rootViewController)
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

// MARK: - Apple Pay Delegate

private class ApplePayDelegate: NSObject, STPApplePayContextDelegate {
  private let completion: (PaymentResult) -> Void
  
  init(completion: @escaping (PaymentResult) -> Void) {
    self.completion = completion
  }
  
  func applePayContext(_ context: STPApplePayContext, didCreatePaymentMethod paymentMethod: STPPaymentMethod, paymentInformation: PKPayment, completion: @escaping STPIntentClientSecretCompletionBlock) {
    // This should be called with the client secret from the payment intent
    // For now, we'll use a placeholder - this needs to be integrated with the actual payment flow
    completion("", nil)
  }
  
  func applePayContext(_ context: STPApplePayContext, didCompleteWith status: STPPaymentStatus, error: Error?) {
    switch status {
    case .success:
      completion(.success)
    case .error:
      completion(.failed)
    case .userCancellation:
      completion(.cancelled)
    @unknown default:
      completion(.cancelled)
    }
  }
}
