import SwiftUI

struct TicketsView: View {
  @EnvironmentObject var app: AppState
  var body: some View {
    NavigationView {
      Group {
        if app.isAuthenticated {
          let cache = TicketsCacheService()
          let tickets = cache.list(orgId: Config.defaultOrgId)
          if tickets.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: "ticket").font(.system(size: 44)).foregroundColor(.secondary)
              Text("No tickets yet").font(.title3).bold()
              Text("Your purchased tickets will appear here.").font(.footnote).foregroundColor(.secondary)
              Spacer()
            }
          } else {
            ScrollView {
              VStack(spacing: 12) {
                ForEach(tickets) { t in TicketRow(ticket: t).padding(.horizontal, 16) }
                Spacer(minLength: 24)
              }
            }
          }
        } else {
          VStack(spacing: 16) {
            Image(systemName: "lock.circle").font(.system(size: 48)).foregroundColor(.white.opacity(0.9))
            Text("Save tickets offline")
              .font(.title3).bold()
            Text("Create an account or sign in to securely store your tickets in the app for offline access on show day.")
              .font(.footnote)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
            NavigationLink("Sign in or create account") { LoginView().environmentObject(app) }
              .buttonStyle(.borderedProminent)
              .tint(StageKit.brandStart)
            Spacer()
          }
          .padding()
          .stageCard()
          .padding(24)
        }
      }
      .navigationTitle("My Tickets")
      .background(StageKit.bgGradient.ignoresSafeArea())
    }
  }
}


