import SwiftUI
import Stripe
// import StripePaymentsUI // PaymentSheet types not found in v24.20.0

struct CheckoutView: View {
  @EnvironmentObject var app: AppState
  let performanceId: String
  let selectedSeats: [String]
  // @State private var paymentSheetPresented = false
  // @State private var paymentResult: PaymentSheetResult?
  @State private var isLoading = false
  @State private var orderResponse: CreateOrderResponse?
  @State private var errorMessage: String?
  
  // @State private var paymentSheet: PaymentSheet?
  
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
      } else if orderResponse != nil {
        // Order created successfully, show retry button if needed
        Button(action: {
          if let response = orderResponse {
            // configurePaymentSheet(clientSecret: response.client_secret) // Disabled until PaymentSheet resolved
            print("[Checkout] Order created: \(response.order_id) - PaymentSheet integration pending")
          }
        }) {
          HStack {
            Image(systemName: "creditcard")
            Text("Show Payment Options")
          }
          .font(.headline)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(Color.green)
          .cornerRadius(12)
        }
      } else {
        // Fallback button if auto-start failed
        Button(action: createOrderAndShowPaymentSheet) {
          HStack {
            Image(systemName: "creditcard")
            Text("Create Order & Pay")
          }
          .font(.headline)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(Color.blue)
          .cornerRadius(12)
        }
        .disabled(isLoading)
      }
      
      // Status Messages
      if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .font(.caption)
      }
      
      Spacer()
    }
    .padding()
    .navigationTitle("Checkout")
    .navigationBarTitleDisplayMode(.inline)
    // .paymentSheet(isPresented: $paymentSheetPresented, paymentSheet: paymentSheet, onCompletion: onPaymentCompletion) // Disabled until PaymentSheet types resolved
    .onAppear {
      // Auto-start order creation when checkout view appears
      if !isLoading && orderResponse == nil {
        createOrderAndShowPaymentSheet()
      }
    }
  }
  
  private func createOrderAndShowPaymentSheet() {
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
        
                        // configurePaymentSheet(clientSecret: response.client_secret) // Disabled until PaymentSheet resolved
                print("[Checkout] Order \(response.order_id) created successfully - PaymentSheet integration pending")
        
      } catch {
        errorMessage = "Failed to create order: \(error.localizedDescription)"
      }
      
      isLoading = false
    }
  }
  
  // private func configurePaymentSheet(clientSecret: String) {
  //   STPAPIClient.shared.publishableKey = Config.stripePublishableKey
  //   
  //   var configuration = PaymentSheet.Configuration()
  //   configuration.merchantDisplayName = "LastMinuteLive"
  //   configuration.allowsDelayedPaymentMethods = true
  //   configuration.applePay = .init(
  //     merchantId: Config.merchantIdentifier,
  //     merchantCountryCode: Config.countryCode
  //   )
  //   
  //   paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
  //   paymentSheetPresented = true
  // }
  
  // private func onPaymentCompletion(result: PaymentSheetResult) {
  //   paymentResult = result
  //   
  //   switch result {
  //   case .completed:
  //     // Payment successful - seats are now confirmed via webhook
  //     errorMessage = "Payment completed successfully! 🎉"
  //     // TODO: Navigate to success screen or dismiss checkout
  //     
  //   case .canceled:
  //     errorMessage = "Payment was cancelled"
  //     
  //   case .failed(let error):
  //     errorMessage = "Payment failed: \(error.localizedDescription)"
  //   }
  // }
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


