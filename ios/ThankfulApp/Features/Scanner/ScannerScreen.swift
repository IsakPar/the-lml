import SwiftUI

struct ScannerScreen: View {
  @EnvironmentObject var app: AppState
  @State private var message: String = "Scan a ticket"
  @State private var showBanner: Bool = false
  var body: some View {
    VStack {
      ScannerView { code in
        handle(code: code)
      }
      if showBanner {
        Text(message)
          .padding()
          .frame(maxWidth: .infinity)
          .background(message.lowercased().contains("valid") || message.lowercased().contains("redeem") ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
          .cornerRadius(8)
          .padding([.horizontal])
      }
    }
    .navigationTitle("Scan")
  }
  private func handle(code: String) {
    // Expect token string or URL containing it
    let token = code
    do {
      _ = try app.verifier.verifyOffline(token: token, expectedTenant: nil)
      message = "Valid offline. Redeeming..."
      showBanner = true
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    } catch {
      message = "Invalid: \(error.localizedDescription)"
      showBanner = true
      UINotificationFeedbackGenerator().notificationOccurred(.error)
      return
    }
    Task {
      do {
        let (_, status) = try await app.verifier.redeem(token: token, orgId: appStateOrg())
        await MainActor.run {
          message = status == "redeemed" ? "Redeemed" : status
          showBanner = true
          UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
      } catch {
        await MainActor.run {
          message = "Online redeem failed"
          showBanner = true
          UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
      }
    }
  }
  private func appStateOrg() -> String { app.accessToken != nil ? (app.api.orgId ?? "") : "" }
}


