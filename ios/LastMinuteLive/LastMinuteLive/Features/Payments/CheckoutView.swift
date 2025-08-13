import SwiftUI
import Stripe

struct CheckoutView: View {
  @EnvironmentObject var app: AppState
  let performanceId: String
  let selectedSeats: [String]
  
  @State private var isLoading = false
  @State private var orderResponse: CreateOrderResponse?
  @State private var errorMessage: String?
  @State private var isProcessingPayment = false
  @StateObject private var paymentProcessor = StripePaymentProcessor()
  
  var totalAmount: Int {
    selectedSeats.count * 2500 // £25 per seat
  }
  
  var body: some View {
    VStack(spacing: 24) {
      // Header
      VStack(spacing: 8) {
        Text("Complete Your Purchase")
          .font(.title2)
          .fontWeight(.semibold)
        
        Text("\(selectedSeats.count) seat\(selectedSeats.count == 1 ? "" : "s") selected")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      
      // Seat Details
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Seats:")
          Spacer()
          Text("\(selectedSeats.count) × £25.00")
        }
        
        Divider()
        
        HStack {
          Text("Total:")
            .fontWeight(.semibold)
          Spacer()
          Text("£\(String(format: "%.2f", Double(totalAmount)/100))")
            .fontWeight(.semibold)
            .font(.title3)
        }
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(12)
      
      // Payment Button
      if isLoading {
        ProgressView("Creating order...")
          .frame(height: 50)
      } else if isProcessingPayment {
        ProgressView("Processing payment...")
          .frame(height: 50)
      } else if orderResponse != nil {
        // Order created successfully - show payment button
        Button(action: processPayment) {
          HStack {
            Image(systemName: "creditcard")
            Text("Pay Now")
          }
          .font(.headline)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(Color.blue)
          .cornerRadius(12)
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
      } else {
        // Initial button to create order
        Button(action: createOrder) {
          HStack {
            Image(systemName: "creditcard")
            Text("Create Order & Pay")
          }
          .font(.headline)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(Color.blue)
          .cornerRadius(12)
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .disabled(isLoading)
      }
      
      // Payment Info
      if orderResponse != nil {
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
      }
      
      // Status Messages
      if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .font(.caption)
          .padding()
          .background(Color.red.opacity(0.1))
          .cornerRadius(8)
      }
      
      if let paymentError = paymentProcessor.errorMessage {
        Text(paymentError)
          .foregroundColor(.red)
          .font(.caption)
          .padding()
          .background(Color.red.opacity(0.1))
          .cornerRadius(8)
      }
      
      Spacer()
    }
    .padding()
    .navigationTitle("Checkout")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      // Auto-create order when checkout view appears
      if !isLoading && orderResponse == nil {
        createOrder()
      }
    }
    .onChange(of: paymentProcessor.paymentState) { state in
      handlePaymentStateChange(state)
    }
  }
  
  private func createOrder() {
    isLoading = true
    errorMessage = nil
    
    Task { @MainActor in
      do {
        // Create order with selected seats
        let requestBody = CreateOrderRequest(
          performance_id: performanceId,
          seat_ids: selectedSeats,
          currency: "GBP",
          total_minor: totalAmount
        )
        
        let bodyData = try JSONEncoder().encode(requestBody)
        let (responseData, _) = try await app.api.request(
          path: "/v1/orders",
          method: "POST",
          body: bodyData,
          headers: ["Idempotency-Key": "order_\(UUID().uuidString)"]
        )
        
        let response = try JSONDecoder().decode(CreateOrderResponse.self, from: responseData)
        self.orderResponse = response
        
        // Configure payment processor with client secret
        paymentProcessor.configure(with: response.client_secret)
        
        print("[Checkout] Order \(response.order_id) created successfully")
        
      } catch {
        errorMessage = "Failed to create order: \(error.localizedDescription)"
      }
      
      isLoading = false
    }
  }
  
  private func processPayment() {
    isProcessingPayment = true
    
    Task {
      let result = await paymentProcessor.presentPaymentOptions()
      
      await MainActor.run {
        isProcessingPayment = false
        // Payment state change will be handled by the onChange modifier
      }
    }
  }
  
  private func handlePaymentStateChange(_ state: PaymentState) {
    switch state {
    case .completed(let result):
      switch result {
      case .success:
        print("[Checkout] Payment successful!")
        errorMessage = nil
        // Show success message or navigate away
        
      case .cancelled:
        print("[Checkout] Payment cancelled")
        
      case .failed:
        print("[Checkout] Payment failed")
        errorMessage = "Payment failed. Please try again."
      }
      
    case .processing:
      isProcessingPayment = true
      
    case .idle:
      isProcessingPayment = false
    }
  }
}

// MARK: - Data Models

struct CreateOrderRequest: Codable {
  let performance_id: String
  let seat_ids: [String]
  let currency: String
  let total_minor: Int
}

struct CreateOrderResponse: Codable {
  let order_id: String
  let client_secret: String
  let status: String
  let currency: String
  let total_minor: Int
  let performance_id: String
  let seat_count: Int
  let trace_id: String?
}