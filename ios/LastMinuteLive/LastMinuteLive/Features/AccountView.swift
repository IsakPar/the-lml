import SwiftUI

struct AccountView: View {
  @EnvironmentObject var app: AppState
  @EnvironmentObject var navigationCoordinator: NavigationCoordinator
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 16) {
          // Profile header
          HStack(spacing: 12) {
            ZStack {
              Circle().fill(Color.white.opacity(0.1)).frame(width: 56, height: 56)
              Image(systemName: "person.fill").foregroundColor(.white.opacity(0.9))
            }
            VStack(alignment: .leading) {
              Text(app.isAuthenticated ? "Signed in" : "Guest")
                .font(.headline)
              Text(app.isAuthenticated ? "Welcome back" : "Sign in to sync and save tickets")
                .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
          }
          .padding(16)
          .stageCard()
          .padding(.horizontal, 16)

          if app.isAuthenticated {
            // When signed in: actions
            VStack(spacing: 12) {
              ActionCard(icon: "creditcard", title: "Payment methods", subtitle: "Manage Apple Pay & cards")
              ActionCard(icon: "bell", title: "Notifications", subtitle: "Show reminders & promos")
              ActionCard(icon: "lock", title: "Security", subtitle: "Face ID & passcodes")
              Button("Sign out") { app.isAuthenticated = false; app.accessToken = nil }
                .buttonStyle(.stageBordered)
            }
            .padding(.horizontal, 16)
          } else {
            // Not signed: premium sign-in callouts
            VStack(spacing: 12) {
              NavigationLink(destination: LoginView().environmentObject(app)) {
                Label("Sign in with Apple", systemImage: "applelogo").frame(maxWidth: .infinity)
              }.buttonStyle(.stagePrimary)
              Button(action: {}) { Label("Sign in with Google", systemImage: "g.circle") }.buttonStyle(.stageBordered)
                .disabled(true)
              Button(action: {}) { Label("Continue with Passkey", systemImage: "key.fill") }.buttonStyle(.stageBordered)
                .disabled(true)
              Text("Google and Passkeys require additional setup and will be enabled soon.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.top, 4)
            }
            .padding(.horizontal, 16)
          }
          Spacer(minLength: 24)
        }
        .padding(.top, 20)
      }
      .navigationTitle("Account")
      .background(StageKit.bgGradient.ignoresSafeArea())
    }
  }
}

private struct ActionCard: View {
  let icon: String
  let title: String
  let subtitle: String
  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(width: 44, height: 44)
        Image(systemName: icon).foregroundColor(.white)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.subheadline)
        Text(subtitle).font(.caption).foregroundColor(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.6))
    }
    .padding(12)
    .stageCard()
  }
}


