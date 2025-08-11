import SwiftUI

struct CheckoutView: View {
  @EnvironmentObject var app: AppState
  let orderId: String
  let amountMinor: Int
  @State private var status: String = ""
  private let applePay = ApplePayHandler()
  var body: some View {
    VStack(spacing: 16) {
      Text("Total: $\(String(format: "%.2f", Double(amountMinor)/100))")
      ApplePayButtonView { startApplePay() }.frame(height: 50)
      if !status.isEmpty { Text(status) }
      Spacer()
    }.padding().navigationTitle("Checkout")
  }
  private func startApplePay() {
    applePay.start(amountMinor: amountMinor, description: "Thankful Order") { ok in
      if ok { status = "Paid" } else { status = "Cancelled" }
    }
  }
}


