import SwiftUI
import AuthenticationServices

struct LoginView: View {
  @EnvironmentObject var app: AppState
  @State private var username: String = ""
  @State private var password: String = ""
  @State private var message: String? = nil
  @State private var isLoading = false
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        Image("AppLogo").resizable().scaledToFit().frame(width: 120, height: 120).padding(.top, 8)
        Text("Welcome back").font(.title2).fontWeight(.semibold)
          .foregroundColor(.white)
        Text("Sign in to sync tickets and checkout faster.")
          .font(.footnote).foregroundColor(.secondary)

        // Federation buttons (Google/Passkey disabled until configured)
        AppleSignInButton(onResult: { result in
          Task { await handleAppleSignIn(result: result) }
        })
        .frame(height: 48)
        Button(action: handleGoogleSignIn) { 
          HStack(spacing: 8) {
            Image(systemName: "g.circle")
            Text("Sign in with Google")
          }
        }
        .buttonStyle(.stageBordered)
        
        Button(action: handlePasskeySignIn) { 
          HStack(spacing: 8) {
            Image(systemName: "key.fill")
            Text("Continue with Passkey")
          }
        }
        .buttonStyle(.stageBordered)
        
        Text("Additional sign-in methods for your convenience.").font(.caption).foregroundColor(.secondary)

        Divider().background(StageKit.hairline)

        VStack(spacing: 12) {
          TextField("Email", text: $username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(12)
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StageKit.hairline, lineWidth: 1))
            .cornerRadius(12)
          SecureField("Password", text: $password)
            .padding(12)
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StageKit.hairline, lineWidth: 1))
            .cornerRadius(12)
          if let msg = message { Text(msg).foregroundColor(.red).font(.footnote) }
          Button(action: login) { if isLoading { ProgressView() } else { Text("Sign in") } }
            .buttonStyle(.stagePrimary)
            .disabled(isLoading || username.isEmpty || password.isEmpty)
        }
        .padding(.top, 6)
        Spacer(minLength: 24)
      }
      .padding(.horizontal, 16)
      .padding(.top, 4)
      .background(StageKit.bgGradient.ignoresSafeArea())
    }
  }
  // MARK: - Authentication Methods (Updated)
  
  @MainActor
  private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
    isLoading = true
    message = nil
    
    let success = await app.handleAppleSignIn(result: result)
    
    if success {
      print("[LoginView] ✅ Apple Sign In successful")
    } else {
      message = app.authenticationManager.lastError ?? "Apple Sign In failed"
      print("[LoginView] ❌ Apple Sign In failed: \(message ?? "unknown error")")
    }
    
    isLoading = false
  }
  
  @MainActor
  private func login() {
    isLoading = true
    message = nil
    
    let email = username.trimmingCharacters(in: .whitespacesAndNewlines)
    
    Task {
      let success = await app.authenticateWithEmail(email, password: password)
      
      if success {
        print("[LoginView] ✅ Email authentication successful")
      } else {
        message = app.authenticationManager.lastError ?? "Login failed"
        print("[LoginView] ❌ Email authentication failed: \(message ?? "unknown error")")
      }
      
      isLoading = false
    }
  }
  
  // MARK: - 🚨 NEW: Additional Authentication Methods
  
  @MainActor
  private func handleGoogleSignIn() {
    print("[LoginView] 🔍 Google Sign In tapped")
    message = nil
    
    // TODO: Implement Google Sign In
    // For now, show a placeholder message
    message = "Google Sign In coming soon! Please use email/password or Apple ID."
    
    // Placeholder implementation:
    // 1. Configure Google Sign In SDK
    // 2. Present Google Sign In flow
    // 3. Handle successful authentication
    // 4. Update app.isAuthenticated = true
  }
  
  @MainActor 
  private func handlePasskeySignIn() {
    print("[LoginView] 🔑 Passkey Sign In tapped")
    message = nil
    
    // TODO: Implement Passkey authentication
    // For now, show a placeholder message
    message = "Passkey authentication coming soon! Please use email/password or Apple ID."
    
    // Placeholder implementation:
    // 1. Check passkey availability
    // 2. Request passkey authentication
    // 3. Handle successful authentication
    // 4. Update app.isAuthenticated = true
  }
}


