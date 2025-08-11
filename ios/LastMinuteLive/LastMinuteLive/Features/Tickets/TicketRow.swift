import SwiftUI

struct TicketRow: View {
  let ticket: CachedTicket
  @State private var showQR = false
  @EnvironmentObject var app: AppState
  @State private var badgeText: String = ""
  @State private var badgeColor: Color = .secondary
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(ticket.seatId).font(.headline)
        Spacer()
        if !badgeText.isEmpty {
          Text(badgeText).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4).background(badgeColor.opacity(0.15)).foregroundColor(badgeColor).cornerRadius(10)
        }
        Button("View QR") { showQR = true }.buttonStyle(.stageBordered)
      }
      Text(ticket.performanceId).font(.subheadline).foregroundColor(.secondary)
      Text("Offline available").font(.caption2).foregroundColor(.secondary)
    }
    .padding(12)
    .stageCard()
    .sheet(isPresented: $showQR) { QRSheet(token: ticket.token) }
    .onAppear(perform: validate)
  }
  private func validate() {
    // Best-effort offline validation
    do {
      try app.verifier.verifyOffline(token: ticket.token, expectedTenant: ticket.tenantId)
      badgeText = "Valid"
      badgeColor = StageKit.success
    } catch {
      badgeText = "Expired or invalid"
      badgeColor = StageKit.warning
    }
  }
}

struct QRSheet: View {
  let token: String
  var body: some View {
    ZStack {
      StageKit.bgGradient.ignoresSafeArea()
      VStack(spacing: 16) {
        Text("Your Ticket").font(.headline)
        QRCodeView(token: token)
          .frame(width: 240, height: 240)
          .padding(24)
          .background(.ultraThinMaterial)
          .cornerRadius(20)
          .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
        Text("Have this ready at the door.").font(.footnote).foregroundColor(.secondary)
        Spacer()
      }.padding()
    }
  }
}


