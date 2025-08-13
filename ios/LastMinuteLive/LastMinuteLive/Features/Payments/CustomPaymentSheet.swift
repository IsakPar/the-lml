import SwiftUI
import Stripe

struct CustomPaymentSheet: View {
  @EnvironmentObject var app: AppState
  @Environment(\.dismiss) private var dismiss
  
  // MARK: - Configuration
  
  let clientSecret: String
  let orderId: String
  let totalAmount: Int
  let currency: String
  let onPaymentCompletion: (PaymentSheetResult) -> Void
  
  // MARK: - State Management
  
  @StateObject private var paymentProcessor = StripePaymentProcessor()
  @State private var formData = PaymentFormData()
  @State private var validationErrors = CardValidationErrors()
  @State private var emailError: String?
  
  // MARK: - Computed Properties
  
  private var orderSummary: OrderSummary {
    let seatCount = totalAmount / 2500 // Assuming £25 per seat
    return OrderSummary(
      seatCount: seatCount,
      totalAmount: totalAmount,
      currency: currency,
      processingFeeIncluded: true
    )
  }
  
  private var paymentConfiguration: PaymentConfiguration {
    PaymentConfiguration(
      clientSecret: clientSecret,
      orderSummary: orderSummary,
      stripePublishableKey: Config.stripePublishableKey,
      appleMerchantIdentifier: Config.merchantIdentifier,
      isApplePayEnabled: true
    )
  }
  
  private var isFormValid: Bool {
    let validation = CardInputValidation.validatePaymentForm(
      cardNumber: formData.cardNumber,
      expiryDate: formData.expiryDate,
      cvc: formData.cvcCode,
      email: formData.email,
      nameOnCard: formData.nameOnCard
    )
    return validation.isValid
  }
  
  // MARK: - Body
  
  var body: some View {
    NavigationView {
      ScrollView {
        PaymentFormContent(
          formData: $formData,
          emailError: $emailError,
          orderSummary: orderSummary,
          validationErrors: validationErrors,
          isFormValid: formData.selectedPaymentMethod == .applePay || isFormValid,
          isProcessing: paymentProcessor.paymentState.isProcessing,
          errorMessage: paymentProcessor.errorMessage,
          isApplePaySupported: paymentProcessor.isApplePaySupported,
          onEmailChanged: validateEmail,
          onCardNumberChanged: { formatAndValidateCardNumber() },
          onExpiryChanged: { formatAndValidateExpiry() },
          onCVCChanged: { formatAndValidateCVC() },
          onPaymentPressed: processPayment
        )
      }
      .navigationTitle("Secure Checkout")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") { dismiss() }
            .foregroundColor(.primary)
        }
      }
      .onAppear { setupPaymentSheet() }
      .onChange(of: paymentProcessor.paymentState) { state in
        handlePaymentStateChange(state)
      }
    }
  }
  
  // MARK: - Setup & Validation
  
  private func setupPaymentSheet() {
    paymentProcessor.configure(with: paymentConfiguration)
    
    // Pre-fill email if user is logged in
    if app.isAuthenticated, let accessToken = app.accessToken {
      formData.email = JWTTokenParser.extractEmail(from: accessToken) ?? ""
    }
  }
  
  private func validateEmail() {
    let result = CardInputValidation.validateEmail(formData.email)
    emailError = result.errorMessage
  }
  
  private func formatAndValidateCardNumber() {
    formData.cardNumber = CardInputFormatting.formatCardNumber(formData.cardNumber)
    updateValidationErrors()
  }
  
  private func formatAndValidateExpiry() {
    formData.expiryDate = CardInputFormatting.formatExpiryDate(formData.expiryDate)
    updateValidationErrors()
  }
  
  private func formatAndValidateCVC() {
    formData.cvcCode = CardInputFormatting.formatCVC(formData.cvcCode)
    updateValidationErrors()
  }
  
  private func updateValidationErrors() {
    let validation = CardInputValidation.validatePaymentForm(
      cardNumber: formData.cardNumber,
      expiryDate: formData.expiryDate,
      cvc: formData.cvcCode,
      email: formData.email,
      nameOnCard: formData.nameOnCard
    )
    validationErrors = validation.errors
  }
  
  // MARK: - Payment Processing
  
  private func processPayment() {
    Task {
      do {
        let result: PaymentResult
        
        if formData.selectedPaymentMethod == .applePay {
          result = try await paymentProcessor.processApplePayPayment()
        } else {
          result = try await paymentProcessor.processCardPayment(with: formData)
        }
        
        await MainActor.run {
          onPaymentCompletion(result.toPaymentSheetResult())
        }
        
      } catch {
        // Error handling is managed by the payment processor
        print("Payment error: \(error)")
      }
    }
  }
  
  private func handlePaymentStateChange(_ state: PaymentState) {
    if case .completed(let result) = state {
      onPaymentCompletion(result.toPaymentSheetResult())
    }
  }
}

// MARK: - Result Conversion

extension PaymentResult {
  func toPaymentSheetResult() -> PaymentSheetResult {
    switch self {
    case .success:
      return .completed
    case .cancelled:
      return .canceled
    case .failed:
      return .failed(PaymentSheetError.unknown(debugDescription: self.message))
    }
  }
}

// MARK: - Payment Sheet Result & Error (for compatibility)

enum PaymentSheetResult {
  case completed
  case canceled
  case failed(Error)
}

enum PaymentSheetError: LocalizedError {
  case unknown(debugDescription: String)
  
  var errorDescription: String? {
    switch self {
    case .unknown(let debugDescription):
      return debugDescription
    }
  }
}

// MARK: - Preview

struct CustomPaymentSheet_Previews: PreviewProvider {
  static var previews: some View {
    CustomPaymentSheet(
      clientSecret: "pi_test_client_secret",
      orderId: "order_123",
      totalAmount: 5000,
      currency: "GBP",
      onPaymentCompletion: { _ in }
    )
    .environmentObject(AppState())
  }
}