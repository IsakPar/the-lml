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
        Button(action: {}) { Label("Sign in with Google", systemImage: "g.circle") }
          .buttonStyle(.stageBordered).disabled(true)
        Button(action: {}) { Label("Continue with Passkey", systemImage: "key.fill") }
          .buttonStyle(.stageBordered).disabled(true)
        Text("Google and Passkeys will be enabled once configured.").font(.caption).foregroundColor(.secondary)

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
}


