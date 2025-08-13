import SwiftUI
import Stripe

struct CheckoutView: View {
  @EnvironmentObject var app: AppState
  let performanceId: String
  let selectedSeats: [String]
  @State private var customPaymentSheetPresented = false
  @State private var isLoading = false
  @State private var orderResponse: CreateOrderResponse?
  @State private var errorMessage: String?
  
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
            // Automatically show custom payment sheet when order is created
            customPaymentSheetPresented = true
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
        // Manual retry button if auto-start failed
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
    .sheet(isPresented: $customPaymentSheetPresented) {
      if let response = orderResponse {
        CustomPaymentSheet(
          clientSecret: response.client_secret,
          orderTotal: response.total_minor,
          seatCount: response.seat_count
        )
        .environmentObject(app)
      }
    }
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
        
                        // Order created successfully - trigger custom payment sheet
                print("[Checkout] Order \(response.order_id) created successfully - showing custom payment sheet")
                customPaymentSheetPresented = true
        
      } catch {
        errorMessage = "Failed to create order: \(error.localizedDescription)"
      }
      
      isLoading = false
    }
  }
  
  // MARK: - Custom Payment Sheet Integration
  // No additional functions needed - CustomPaymentSheet handles everything internally
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


