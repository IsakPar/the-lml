import SwiftUI

struct TicketsView: View {
  @EnvironmentObject var app: AppState
  @State private var tickets: [CachedTicket] = []
  var body: some View {
    List(tickets, id: \.jti) { t in
      VStack(alignment: .leading) {
        Text(t.seatId).font(.headline)
        Text(t.performanceId).font(.subheadline).foregroundColor(.secondary)
      }
    }
    .navigationTitle("My Tickets")
    .onAppear { load() }
  }
  private func load() {
    let org = Config.defaultOrgId
    let cache = TicketsCacheService()
    tickets = cache.list(orgId: org)
  }
}


