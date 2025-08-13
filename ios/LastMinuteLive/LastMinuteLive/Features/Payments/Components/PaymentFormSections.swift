import SwiftUI
import Foundation

// MARK: - Email Section

struct EmailSection: View {
  @Binding var email: String
  let emailError: String?
  let onEmailChanged: () -> Void
  
  var body: some View {
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
            onEmailChanged()
          }
        
        ValidationErrorText(errorMessage: emailError)
      }
    }
  }
}

// MARK: - Card Details Section

struct CardDetailsSection: View {
  @Binding var formData: PaymentFormData
  let validationErrors: CardValidationErrors
  let onCardNumberChanged: () -> Void
  let onExpiryChanged: () -> Void
  let onCVCChanged: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Name on card
      VStack(alignment: .leading, spacing: 4) {
        TextField("Name on card", text: $formData.nameOnCard)
          .textFieldStyle(CustomTextFieldStyle())
          .textContentType(.name)
      }
      
      // Card number
      VStack(alignment: .leading, spacing: 4) {
        TextField("Card number", text: $formData.cardNumber)
          .textFieldStyle(CustomTextFieldStyle())
          .keyboardType(.numberPad)
          .textContentType(.creditCardNumber)
          .onChange(of: formData.cardNumber) { _ in
            onCardNumberChanged()
          }
        
        ValidationErrorText(errorMessage: validationErrors.cardNumber)
      }
      
      // Expiry and CVC row
      HStack(spacing: 12) {
        // Expiry date
        VStack(alignment: .leading, spacing: 4) {
          TextField("MM/YY", text: $formData.expiryDate)
            .textFieldStyle(CustomTextFieldStyle())
            .keyboardType(.numberPad)
            .onChange(of: formData.expiryDate) { _ in
              onExpiryChanged()
            }
          
          ValidationErrorText(errorMessage: validationErrors.expiry)
        }
        
        // CVC
        VStack(alignment: .leading, spacing: 4) {
          TextField("CVC", text: $formData.cvcCode)
            .textFieldStyle(CustomTextFieldStyle())
            .keyboardType(.numberPad)
            .onChange(of: formData.cvcCode) { _ in
              onCVCChanged()
            }
          
          ValidationErrorText(errorMessage: validationErrors.cvc)
        }
      }
    }
  }
}

// MARK: - Payment Button Section

struct PaymentButtonSection: View {
  let isFormValid: Bool
  let isProcessing: Bool
  let selectedMethod: PaymentMethodType
  let formattedTotal: String
  let errorMessage: String?
  let onPaymentPressed: () -> Void
  
  var body: some View {
    VStack(spacing: 16) {
      PaymentButton(
        isEnabled: isFormValid,
        isProcessing: isProcessing,
        selectedMethod: selectedMethod,
        formattedTotal: formattedTotal,
        action: onPaymentPressed
      )
      
      ErrorMessageView(message: errorMessage)
      
      SecurityMessage()
    }
  }
}

// MARK: - Complete Payment Form

struct PaymentFormContent: View {
  @Binding var formData: PaymentFormData
  @Binding var emailError: String?
  
  let orderSummary: OrderSummary
  let validationErrors: CardValidationErrors
  let isFormValid: Bool
  let isProcessing: Bool
  let errorMessage: String?
  let isApplePaySupported: Bool
  
  let onEmailChanged: () -> Void
  let onCardNumberChanged: () -> Void
  let onExpiryChanged: () -> Void
  let onCVCChanged: () -> Void
  let onPaymentPressed: () -> Void
  
  var body: some View {
    VStack(spacing: 24) {
      // Header with branding
      BrandHeader()
      
      // Order summary
      OrderSummaryCard(orderSummary: orderSummary)
      
      // Email section
      EmailSection(
        email: $formData.email,
        emailError: emailError,
        onEmailChanged: onEmailChanged
      )
      
      // Payment method selection
      PaymentMethodSelector(
        selectedMethod: $formData.selectedPaymentMethod,
        isApplePaySupported: isApplePaySupported
      )
      
      // Card details (when card is selected)
      if formData.selectedPaymentMethod == .card {
        CardDetailsSection(
          formData: $formData,
          validationErrors: validationErrors,
          onCardNumberChanged: onCardNumberChanged,
          onExpiryChanged: onExpiryChanged,
          onCVCChanged: onCVCChanged
        )
      }
      
      // Payment button
      PaymentButtonSection(
        isFormValid: isFormValid,
        isProcessing: isProcessing,
        selectedMethod: formData.selectedPaymentMethod,
        formattedTotal: orderSummary.formattedTotal,
        errorMessage: errorMessage,
        onPaymentPressed: onPaymentPressed
      )
      
      // Powered by Stripe footer
      PoweredByStripeFooter()
      
      Spacer(minLength: 50)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }
}
