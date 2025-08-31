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
              Circle()
                .fill(app.isAuthenticated ? AnyShapeStyle(StageKit.brandGradient) : AnyShapeStyle(Color.white.opacity(0.1)))
                .frame(width: 56, height: 56)
              
              if app.isAuthenticated {
                // Show user's initial or Apple logo based on auth method
                if let user = app.authenticationManager.currentUser, user.provider == .apple {
                  Image(systemName: "applelogo")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .medium))
                } else {
                  // Show first letter of email/name
                  Text(getUserInitial())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                }
              } else {
                Image(systemName: "person.fill")
                  .foregroundColor(.white.opacity(0.9))
              }
            }
            
            VStack(alignment: .leading, spacing: 2) {
              if app.isAuthenticated {
                // Show actual user name or email
                if let user = app.authenticationManager.currentUser {
                  Text(user.name ?? "Account User")
                    .font(.headline)
                    .foregroundColor(.white)
                  
                  Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                  
                  // Show verification status
                  if !user.isVerified {
                    Text("• Email not verified")
                      .font(.caption)
                      .foregroundColor(.orange)
                  }
                } else {
                  Text("Signed In")
                    .font(.headline)
                    .foregroundColor(.white)
                  
                  Text("Welcome back")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                }
              } else {
                Text("Guest")
                  .font(.headline)
                  .foregroundColor(.white)
                
                Text("Sign in to sync and save tickets")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            }
            Spacer()
          }
          .padding(16)
          .stageCard()
          .padding(.horizontal, 16)

          if app.isAuthenticated {
            // When signed in: actions
            VStack(spacing: 12) {
              
              // Purchase History
              ActionCard(
                icon: "ticket.fill", 
                title: "My Tickets", 
                subtitle: "View purchased tickets (\(getTicketCount()))",
                action: {
                  navigationCoordinator.navigateToTickets()
                }
              )
              
              // Payment Methods
              ActionCard(
                icon: "creditcard", 
                title: "Payment Methods", 
                subtitle: "Manage Apple Pay & saved cards",
                action: { 
                  // TODO: Navigate to payment methods management
                  print("[Account] Payment Methods tapped")
                }
              )
              
              // Notifications
              ActionCard(
                icon: "bell", 
                title: "Notifications", 
                subtitle: "Event reminders & promotions",
                action: {
                  // TODO: Navigate to notification settings
                  print("[Account] Notifications tapped")
                }
              )
              
              // Security Settings
              ActionCard(
                icon: "lock", 
                title: "Privacy & Security", 
                subtitle: "Face ID, data & account security",
                action: {
                  // TODO: Navigate to security settings
                  print("[Account] Security tapped")
                }
              )
              
              // Account Settings
              ActionCard(
                icon: "person.circle", 
                title: "Account Settings", 
                subtitle: "Edit profile & preferences",
                action: {
                  // TODO: Navigate to account settings
                  print("[Account] Account Settings tapped")
                }
              )
              
              // Support
              ActionCard(
                icon: "questionmark.circle", 
                title: "Help & Support", 
                subtitle: "FAQs, contact support",
                action: {
                  // TODO: Navigate to support/help
                  print("[Account] Support tapped")
                }
              )
              
              // Sign out button
              Button(action: {
                Task {
                  await app.logout()
                }
              }) {
                HStack {
                  Image(systemName: "arrow.right.square")
                  Text("Sign Out")
                }
                .frame(maxWidth: .infinity)
              }
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
          // ✅ FIXED: Ensure sign-out button is accessible with proper bottom padding
          Spacer(minLength: 100) // Increased from 24 to ensure button clears navigation
        }
        .padding(.top, 20)
        .padding(.bottom, 20) // ✅ ADDED: Bottom padding for safe area
      }
      .scrollBounceBehavior(.basedOnSize) // ✅ ADDED: Prevent unnecessary bounce
      .navigationTitle("Account")
      .background(StageKit.bgGradient.ignoresSafeArea())
    }
  }
  
  // MARK: - Helper Methods
  
  private func getUserInitial() -> String {
    if let user = app.authenticationManager.currentUser {
      if let name = user.name, let firstChar = name.first {
        return String(firstChar).uppercased()
      } else if let firstChar = user.email.first {
        return String(firstChar).uppercased()
      }
    }
    return "U"
  }
  
  private func getTicketCount() -> Int {
    return app.ticketStorageService?.tickets.count ?? 0
  }
}

// MARK: - ActionCard Component

private struct ActionCard: View {
  let icon: String
  let title: String
  let subtitle: String
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.08))
            .frame(width: 44, height: 44)
          Image(systemName: icon)
            .foregroundColor(StageKit.brandEnd)
            .font(.system(size: 18, weight: .medium))
        }
        
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
          
          Text(subtitle)
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
        }
        
        Spacer()
        
        Image(systemName: "chevron.right")
          .foregroundColor(.white.opacity(0.6))
          .font(.system(size: 14, weight: .medium))
      }
      .padding(12)
      .stageCard()
    }
    .buttonStyle(PlainButtonStyle())
  }
}


