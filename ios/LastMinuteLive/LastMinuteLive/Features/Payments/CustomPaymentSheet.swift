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
  @State private var isProcessing = false
  
  // MARK: - Body
  
  var body: some View {
    VStack(spacing: 24) {
      // Payment summary
      VStack(spacing: 16) {
        Image(systemName: "creditcard.fill")
          .font(.system(size: 48))
          .foregroundColor(.blue)
        
        Text("Complete Your Payment")
          .font(.title2)
          .fontWeight(.semibold)
        
        Text("Order: \(orderId)")
          .font(.caption)
          .foregroundColor(.secondary)
        
        Text(formattedTotal)
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(.blue)
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(16)
      
      // Payment button
      Button(action: processPayment) {
        HStack {
          if isProcessing {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.8)
          } else {
            Image(systemName: "creditcard")
            Text("Pay Now")
              .fontWeight(.semibold)
          }
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(isProcessing ? Color.gray : Color.blue)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
      }
      .disabled(isProcessing)
      
      // Status messages
      if let errorMessage = paymentProcessor.errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .font(.caption)
          .multilineTextAlignment(.center)
          .padding()
          .background(Color.red.opacity(0.1))
          .cornerRadius(8)
      }
      
      // Payment info
      VStack(spacing: 8) {
        HStack {
          Image(systemName: "lock.shield.fill")
            .foregroundColor(.green)
          Text("Secure payment powered by Stripe")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        HStack {
          Image(systemName: "applelogo")
            .foregroundColor(.primary)
          Image(systemName: "creditcard.fill")
            .foregroundColor(.primary)
          Text("• Cards & Apple Pay supported")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(12)
      
      Spacer()
    }
    .padding()
    .navigationTitle("Payment")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Cancel") { 
          onPaymentCompletion(.canceled)
          dismiss() 
        }
        .foregroundColor(.primary)
      }
    }
    .onAppear {
      configurePaymentProcessor()
    }
    .onChange(of: paymentProcessor.paymentState) { state in
      handlePaymentStateChange(state)
    }
    .onChange(of: paymentProcessor.paymentState.isProcessing) { processing in
      isProcessing = processing
    }
  }
  
  // MARK: - Helper Properties
  
  private var formattedTotal: String {
    String(format: "£%.2f", Double(totalAmount) / 100)
  }
  
  // MARK: - Payment Processing
  
  private func configurePaymentProcessor() {
    paymentProcessor.configure(with: clientSecret)
  }
  
  private func processPayment() {
    Task {
      let result = await paymentProcessor.presentPaymentOptions()
      await MainActor.run {
        // Result handling is done via state change
      }
    }
  }
  
  private func handlePaymentStateChange(_ state: PaymentState) {
    if case .completed(let result) = state {
      onPaymentCompletion(result.toPaymentSheetResult())
      
      // Add delay for success message, then dismiss
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        dismiss()
      }
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