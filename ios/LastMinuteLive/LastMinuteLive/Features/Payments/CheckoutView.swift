import SwiftUI
import PassKit

struct CheckoutView: View {
  @EnvironmentObject var app: AppState
  let orderId: String
  let amountMinor: Int
  @State private var status: String = ""
  private let applePay = ApplePayHandler()
  var body: some View {
    VStack(spacing: 16) {
      Text("Total: £\(String(format: "%.2f", Double(amountMinor)/100))")
       ApplePayButtonView { startApplePay() }.frame(height: 50)
      if !status.isEmpty { Text(status) }
      Spacer()
    }.padding().navigationTitle("Checkout")
  }
  private func startApplePay() {
    guard PKPaymentAuthorizationController.canMakePayments() else { status = "Apple Pay unavailable"; return }
    applePay.start(amountMinor: amountMinor, description: "LastMinuteLive Order") { ok in
      if ok {
        status = "Paid"
        Task { await app.issueAndCacheTicket(orderId: orderId, performanceId: "perf_demo", seatId: "A-1") }
      } else {
        status = "Cancelled"
      }
    }
  }
}


