import SwiftUI
import Foundation

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

// MARK: - Payment Method Selector

struct PaymentMethodSelector: View {
  @Binding var selectedMethod: PaymentMethodType
  let isApplePaySupported: Bool
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Payment Method")
        .font(.headline)
        .foregroundColor(.primary)
      
      VStack(spacing: 12) {
        // Apple Pay option (if available)
        if isApplePaySupported {
          PaymentMethodRow(
            method: .applePay,
            isSelected: selectedMethod == .applePay
          ) {
            selectedMethod = .applePay
          }
        }
        
        // Card payment option
        PaymentMethodRow(
          method: .card,
          isSelected: selectedMethod == .card
        ) {
          selectedMethod = .card
        }
      }
    }
  }
}

// MARK: - Payment Method Row

struct PaymentMethodRow: View {
  let method: PaymentMethodType
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack {
        Image(systemName: method.iconName)
          .font(.title3)
        
        Text(method.displayName)
          .font(.body)
          .fontWeight(.medium)
        
        Spacer()
        
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundColor(isSelected ? .blue : .gray)
      }
      .padding(16)
      .background(Color(.systemGray6))
      .cornerRadius(12)
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - Brand Header

struct BrandHeader: View {
  var body: some View {
    VStack(spacing: 12) {
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
        
        SecurityBadge()
      }
      
      Divider()
    }
  }
}

// MARK: - Security Badge

struct SecurityBadge: View {
  var body: some View {
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
}

// MARK: - Order Summary Card

struct OrderSummaryCard: View {
  let orderSummary: OrderSummary
  
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Order Summary")
          .font(.headline)
          .foregroundColor(.primary)
        Spacer()
      }
      
      VStack(spacing: 8) {
        HStack {
          Text(orderSummary.seatDescription)
            .foregroundColor(.primary)
          Spacer()
          Text(orderSummary.formattedTotal)
            .fontWeight(.medium)
            .foregroundColor(.primary)
        }
        
        HStack {
          Text("Processing fee")
            .foregroundColor(.secondary)
          Spacer()
          Text(orderSummary.processingFeeDescription)
            .foregroundColor(.secondary)
        }
        
        Divider()
        
        HStack {
          Text("Total")
            .font(.headline)
            .fontWeight(.semibold)
          Spacer()
          Text(orderSummary.formattedTotal)
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
}

// MARK: - Payment Button

struct PaymentButton: View {
  let isEnabled: Bool
  let isProcessing: Bool
  let selectedMethod: PaymentMethodType
  let formattedTotal: String
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack {
        if isProcessing {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(0.8)
        } else {
          Image(systemName: selectedMethod.iconName)
          
          Text(buttonText)
            .fontWeight(.semibold)
        }
      }
      .font(.headline)
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(buttonBackgroundColor)
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    .disabled(!isEnabled || isProcessing)
  }
  
  private var buttonText: String {
    switch selectedMethod {
    case .applePay:
      return "Pay with Apple Pay"
    case .card:
      return "Pay \(formattedTotal)"
    }
  }
  
  private var buttonBackgroundColor: Color {
    return isEnabled && !isProcessing ? Color.blue : Color.gray
  }
}

// MARK: - Error Message View

struct ErrorMessageView: View {
  let message: String?
  
  var body: some View {
    Group {
      if let message = message {
        Text(message)
          .font(.caption)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
      }
    }
  }
}

// MARK: - Security Message

struct SecurityMessage: View {
  var body: some View {
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

struct PoweredByStripeFooter: View {
  var body: some View {
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

// MARK: - Validation Error Text

struct ValidationErrorText: View {
  let errorMessage: String?
  
  var body: some View {
    Group {
      if let errorMessage = errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundColor(.red)
      }
    }
  }
}
