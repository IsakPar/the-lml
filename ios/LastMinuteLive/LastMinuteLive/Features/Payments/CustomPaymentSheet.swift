import SwiftUI
import Stripe

struct CustomPaymentSheet: View {
  @EnvironmentObject var app: AppState
  @Environment(\.dismiss) private var dismiss
  
  let clientSecret: String
  let orderTotal: Int
  let seatCount: Int
  
  // Payment form state
  @State private var cardNumber = ""
  @State private var expiryDate = ""
  @State private var cvcCode = ""
  @State private var email = ""
  @State private var nameOnCard = ""
  
  // UI state
  @State private var isProcessing = false
  @State private var paymentResult: PaymentResult?
  @State private var errorMessage: String?
  @State private var showingApplePay = false
  
  // Validation state
  @State private var cardNumberError: String?
  @State private var expiryError: String?
  @State private var cvcError: String?
  @State private var emailError: String?
  
  var formattedTotal: String {
    String(format: "£%.2f", Double(orderTotal) / 100)
  }
  
  var isFormValid: Bool {
    !cardNumber.isEmpty && cardNumber.count >= 16 &&
    !expiryDate.isEmpty && expiryDate.count >= 5 &&
    !cvcCode.isEmpty && cvcCode.count >= 3 &&
    !email.isEmpty && email.contains("@") &&
    !nameOnCard.isEmpty &&
    cardNumberError == nil && expiryError == nil && cvcError == nil && emailError == nil
  }
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Header with LastMinuteLive branding
          headerSection
          
          // Order summary
          orderSummarySection
          
          // Email field (with prefill for logged users)
          emailSection
          
          // Payment method selection
          paymentMethodSection
          
          // Card details (when card is selected)
          if !showingApplePay {
            cardDetailsSection
          }
          
          // Payment button
          paymentButtonSection
          
          // Powered by Stripe footer
          poweredByStripeFooter
          
          Spacer(minLength: 50)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
      .navigationTitle("Secure Checkout")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.primary)
        }
      }
      .onAppear {
        setupInitialValues()
        configureStripe()
      }
      .alert("Payment Result", isPresented: .constant(paymentResult != nil)) {
        Button("OK") {
          if paymentResult == .success {
            dismiss()
          }
          paymentResult = nil
        }
      } message: {
        Text(paymentResultMessage)
      }
    }
  }
  
  // MARK: - Header Section
  private var headerSection: some View {
    VStack(spacing: 12) {
      // LastMinuteLive logo/branding
      HStack {
        Image(systemName: "ticket.fill")
          .font(.title2)
          .foregroundColor(.blue)
        
        VStack(alignment: .leading, spacing: 2) {
          Text("LastMinuteLive")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
          
          Text("Secure Payment")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        // Security badge
        HStack(spacing: 4) {
          Image(systemName: "lock.shield.fill")
            .font(.caption)
            .foregroundColor(.green)
          Text("Secure")
            .font(.caption2)
            .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
      }
      
      Divider()
    }
  }
  
  // MARK: - Order Summary Section
  private var orderSummarySection: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Order Summary")
          .font(.headline)
          .foregroundColor(.primary)
        Spacer()
      }
      
      VStack(spacing: 8) {
        HStack {
          Text("\(seatCount) seat\(seatCount == 1 ? "" : "s")")
            .foregroundColor(.primary)
          Spacer()
          Text(formattedTotal)
            .fontWeight(.medium)
            .foregroundColor(.primary)
        }
        
        HStack {
          Text("Processing fee")
            .foregroundColor(.secondary)
          Spacer()
          Text("Included")
            .foregroundColor(.secondary)
        }
        
        Divider()
        
        HStack {
          Text("Total")
            .font(.headline)
            .fontWeight(.semibold)
          Spacer()
          Text(formattedTotal)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.blue)
        }
      }
      .padding(16)
      .background(Color(.systemGray6))
      .cornerRadius(12)
    }
  }
  
  // MARK: - Email Section
  private var emailSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Contact Information")
        .font(.headline)
        .foregroundColor(.primary)
      
      VStack(alignment: .leading, spacing: 4) {
        TextField("Email address", text: $email)
          .textFieldStyle(CustomTextFieldStyle())
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .autocapitalization(.none)
          .onChange(of: email) { _ in
            validateEmail()
          }
        
        if let emailError = emailError {
          Text(emailError)
            .font(.caption)
            .foregroundColor(.red)
        }
      }
    }
  }
  
  // MARK: - Payment Method Section
  private var paymentMethodSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Payment Method")
        .font(.headline)
        .foregroundColor(.primary)
      
      // Apple Pay option (if available)
      if STPAPIClient.shared.deviceSupportsApplePay() {
        Button(action: {
          showingApplePay.toggle()
        }) {
          HStack {
            Image(systemName: "applelogo")
              .font(.title3)
            Text("Apple Pay")
              .font(.body)
              .fontWeight(.medium)
            Spacer()
            Image(systemName: showingApplePay ? "checkmark.circle.fill" : "circle")
              .foregroundColor(showingApplePay ? .blue : .gray)
          }
          .padding(16)
          .background(Color(.systemGray6))
          .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
      }
      
      // Card payment option
      Button(action: {
        showingApplePay = false
      }) {
        HStack {
          Image(systemName: "creditcard")
            .font(.title3)
          Text("Credit or Debit Card")
            .font(.body)
            .fontWeight(.medium)
          Spacer()
          Image(systemName: !showingApplePay ? "checkmark.circle.fill" : "circle")
            .foregroundColor(!showingApplePay ? .blue : .gray)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }
  
  // MARK: - Card Details Section
  private var cardDetailsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Name on card
      VStack(alignment: .leading, spacing: 4) {
        TextField("Name on card", text: $nameOnCard)
          .textFieldStyle(CustomTextFieldStyle())
          .textContentType(.name)
      }
      
      // Card number
      VStack(alignment: .leading, spacing: 4) {
        TextField("Card number", text: $cardNumber)
          .textFieldStyle(CustomTextFieldStyle())
          .keyboardType(.numberPad)
          .textContentType(.creditCardNumber)
          .onChange(of: cardNumber) { _ in
            formatCardNumber()
            validateCardNumber()
          }
        
        if let cardNumberError = cardNumberError {
          Text(cardNumberError)
            .font(.caption)
            .foregroundColor(.red)
        }
      }
      
      // Expiry and CVC
      HStack(spacing: 12) {
        // Expiry date
        VStack(alignment: .leading, spacing: 4) {
          TextField("MM/YY", text: $expiryDate)
            .textFieldStyle(CustomTextFieldStyle())
            .keyboardType(.numberPad)
            .onChange(of: expiryDate) { _ in
              formatExpiryDate()
              validateExpiryDate()
            }
          
          if let expiryError = expiryError {
            Text(expiryError)
              .font(.caption)
              .foregroundColor(.red)
          }
        }
        
        // CVC
        VStack(alignment: .leading, spacing: 4) {
          TextField("CVC", text: $cvcCode)
            .textFieldStyle(CustomTextFieldStyle())
            .keyboardType(.numberPad)
            .onChange(of: cvcCode) { _ in
              formatCVC()
              validateCVC()
            }
          
          if let cvcError = cvcError {
            Text(cvcError)
              .font(.caption)
              .foregroundColor(.red)
          }
        }
      }
    }
  }
  
  // MARK: - Payment Button Section
  private var paymentButtonSection: some View {
    VStack(spacing: 16) {
      Button(action: processPayment) {
        HStack {
          if isProcessing {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.8)
          } else {
            Image(systemName: showingApplePay ? "applelogo" : "creditcard")
            Text(showingApplePay ? "Pay with Apple Pay" : "Pay \(formattedTotal)")
              .fontWeight(.semibold)
          }
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(isFormValid && !isProcessing ? Color.blue : Color.gray)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
      }
      .disabled(!isFormValid || isProcessing)
      
      if let errorMessage = errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
      }
      
      // Security message
      HStack {
        Image(systemName: "lock.fill")
          .font(.caption)
          .foregroundColor(.green)
        Text("Your payment information is secure and encrypted")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
  
  // MARK: - Powered by Stripe Footer
  private var poweredByStripeFooter: some View {
    VStack(spacing: 8) {
      Divider()
      
      HStack {
        Spacer()
        Text("Powered by")
          .font(.caption2)
          .foregroundColor(.secondary)
        Text("Stripe")
          .font(.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.blue)
        Spacer()
      }
    }
    .padding(.top, 20)
  }
}

// MARK: - Helper Functions
extension CustomPaymentSheet {
  private func setupInitialValues() {
    // Pre-fill email if user is logged in
    if app.isAuthenticated, let accessToken = app.accessToken {
      email = extractEmailFromToken(accessToken) ?? ""
    }
  }
  
  private func extractEmailFromToken(_ token: String) -> String? {
    // JWT tokens are typically in format: header.payload.signature
    let components = token.components(separatedBy: ".")
    guard components.count >= 2 else { return nil }
    
    let payloadBase64 = components[1]
    
    // Add padding if needed for base64 decoding
    var paddedPayload = payloadBase64
    let padding = 4 - (payloadBase64.count % 4)
    if padding != 4 {
      paddedPayload += String(repeating: "=", count: padding)
    }
    
    // Replace URL-safe characters
    paddedPayload = paddedPayload
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    
    guard let payloadData = Data(base64Encoded: paddedPayload),
          let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
      return nil
    }
    
    // Look for common email fields in JWT payload
    return payload["email"] as? String ?? 
           payload["sub"] as? String ?? 
           payload["preferred_username"] as? String
  }
  
  private func configureStripe() {
    STPAPIClient.shared.publishableKey = Config.stripePublishableKey
  }
  
  private func formatCardNumber() {
    let digits = cardNumber.replacingOccurrences(of: " ", with: "")
    let formatted = digits.enumerated().compactMap { index, character in
      return (index > 0 && index % 4 == 0) ? " \(character)" : "\(character)"
    }.joined()
    
    if formatted != cardNumber && formatted.count <= 19 {
      cardNumber = formatted
    }
  }
  
  private func formatExpiryDate() {
    let digits = expiryDate.replacingOccurrences(of: "/", with: "")
    if digits.count >= 2 {
      let month = String(digits.prefix(2))
      let year = String(digits.dropFirst(2))
      let formatted = year.isEmpty ? month : "\(month)/\(year)"
      if formatted != expiryDate && formatted.count <= 5 {
        expiryDate = formatted
      }
    }
  }
  
  private func formatCVC() {
    let digits = cvcCode.filter { $0.isNumber }
    if digits.count <= 4 {
      cvcCode = digits
    }
  }
  
  private func validateCardNumber() {
    let digits = cardNumber.replacingOccurrences(of: " ", with: "")
    if digits.isEmpty {
      cardNumberError = nil
    } else if digits.count < 13 {
      cardNumberError = "Card number too short"
    } else if digits.count > 19 {
      cardNumberError = "Card number too long"
    } else {
      cardNumberError = nil
    }
  }
  
  private func validateExpiryDate() {
    if expiryDate.isEmpty {
      expiryError = nil
      return
    }
    
    let components = expiryDate.split(separator: "/")
    guard components.count == 2,
          let month = Int(components[0]),
          let year = Int(components[1]) else {
      expiryError = "Invalid format (MM/YY)"
      return
    }
    
    if month < 1 || month > 12 {
      expiryError = "Invalid month"
      return
    }
    
    let currentYear = Calendar.current.component(.year, from: Date()) % 100
    let currentMonth = Calendar.current.component(.month, from: Date())
    
    if year < currentYear || (year == currentYear && month < currentMonth) {
      expiryError = "Card expired"
      return
    }
    
    expiryError = nil
  }
  
  private func validateCVC() {
    if cvcCode.isEmpty {
      cvcError = nil
    } else if cvcCode.count < 3 {
      cvcError = "CVC too short"
    } else {
      cvcError = nil
    }
  }
  
  private func validateEmail() {
    if email.isEmpty {
      emailError = nil
    } else if !email.contains("@") || !email.contains(".") {
      emailError = "Invalid email format"
    } else {
      emailError = nil
    }
  }
  
  private func processPayment() {
    guard !isProcessing else { return }
    
    isProcessing = true
    errorMessage = nil
    
    if showingApplePay {
      processApplePayPayment()
    } else {
      processCardPayment()
    }
  }
  
  private func processCardPayment() {
    Task { @MainActor in
      do {
        // Create payment method parameters
        let cardParams = STPPaymentMethodCardParams()
        cardParams.number = cardNumber.replacingOccurrences(of: " ", with: "")
        
        let expiryComponents = expiryDate.split(separator: "/")
        if expiryComponents.count == 2 {
          cardParams.expMonth = NSNumber(value: Int(expiryComponents[0]) ?? 0)
          cardParams.expYear = NSNumber(value: Int("20\(expiryComponents[1])") ?? 0)
        }
        cardParams.cvc = cvcCode
        
        let billingDetails = STPPaymentMethodBillingDetails()
        billingDetails.email = email
        billingDetails.name = nameOnCard
        
        let paymentMethodParams = STPPaymentMethodParams(card: cardParams, billingDetails: billingDetails, metadata: nil)
        
        // Confirm payment with Stripe
        let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
        paymentIntentParams.paymentMethodParams = paymentMethodParams
        
        let paymentHandler = STPPaymentHandler.shared()
        
        paymentHandler.confirmPayment(paymentIntentParams, with: UIApplication.shared.windows.first?.rootViewController ?? UIViewController()) { status, paymentIntent, error in
          DispatchQueue.main.async {
            self.isProcessing = false
            
            switch status {
            case .succeeded:
              self.paymentResult = .success
            case .canceled:
              self.paymentResult = .cancelled
            case .failed:
              self.errorMessage = error?.localizedDescription ?? "Payment failed"
              self.paymentResult = .failed
            @unknown default:
              self.errorMessage = "Unknown payment status"
              self.paymentResult = .failed
            }
          }
        }
        
      } catch {
        isProcessing = false
        errorMessage = error.localizedDescription
      }
    }
  }
  
  private func processApplePayPayment() {
    // Apple Pay implementation
    // This would integrate with your existing Apple Pay configuration
    isProcessing = false
    errorMessage = "Apple Pay integration coming soon"
  }
  
  private var paymentResultMessage: String {
    switch paymentResult {
    case .success:
      return "Payment successful! Your seats are confirmed. 🎉"
    case .cancelled:
      return "Payment was cancelled."
    case .failed:
      return "Payment failed. Please try again."
    case .none:
      return ""
    }
  }
}

// MARK: - Payment Result Enum
enum PaymentResult {
  case success
  case cancelled
  case failed
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color(.systemGray6))
      .cornerRadius(10)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color.gray.opacity(0.3), lineWidth: 1)
      )
  }
}

// MARK: - Preview
struct CustomPaymentSheet_Previews: PreviewProvider {
  static var previews: some View {
    CustomPaymentSheet(
      clientSecret: "pi_test_client_secret",
      orderTotal: 5000, // £50.00
      seatCount: 2
    )
    .environmentObject(AppState())
  }
}
