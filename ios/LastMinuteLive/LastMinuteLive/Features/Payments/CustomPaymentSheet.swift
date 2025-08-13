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
  @State private var showPaymentSheet = false
  
  // MARK: - Body
  
  var body: some View {
    VStack(spacing: 24) {
      // Payment summary
      VStack(spacing: 16) {
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
      
      // Payment button
      Button(action: presentPaymentSheet) {
        HStack {
          Image(systemName: "creditcard")
          Text("Pay with Stripe")
            .fontWeight(.semibold)
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.blue)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
      }
      .disabled(paymentProcessor.paymentState.isProcessing)
      
      // Status messages
      if let errorMessage = paymentProcessor.errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .font(.caption)
          .multilineTextAlignment(.center)
      }
      
      // Powered by Stripe footer
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
      
      Spacer()
    }
    .padding()
    .navigationTitle("Payment")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Cancel") { dismiss() }
          .foregroundColor(.primary)
      }
    }
    .onAppear {
      configurePaymentProcessor()
    }
    .onChange(of: paymentProcessor.paymentState) { state in
      handlePaymentStateChange(state)
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
  
  private func presentPaymentSheet() {
    _ = paymentProcessor.presentPaymentSheet()
  }
  
  private func handlePaymentStateChange(_ state: PaymentState) {
    if case .completed(let result) = state {
      onPaymentCompletion(result.toPaymentSheetResult())
      dismiss()
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