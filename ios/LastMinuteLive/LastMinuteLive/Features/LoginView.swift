import SwiftUI

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
        AppleSignInButton(onToken: { token in
          Task { await signInWithApple(identityToken: token) }
        }, onError: { err in self.message = err?.localizedDescription ?? "Apple sign-in cancelled" })
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
  @MainActor
  private func signInWithApple(identityToken: String) async {
    do {
      let payload = try JSONSerialization.data(withJSONObject: ["identityToken": identityToken])
      let (resp, _) = try await app.api.request(path: "/v1/auth/apple", method: "POST", body: payload, headers: ["X-Org-ID": Config.defaultOrgId])
      let obj = try JSONSerialization.jsonObject(with: resp) as? [String: Any]
      if let t = obj?["access_token"] as? String { app.accessToken = t; app.api.accessToken = t; app.api.orgId = Config.defaultOrgId; app.isAuthenticated = true; app.verifierStartRefresh() }
      else { message = "Unable to sign in with Apple" }
    } catch { message = error.localizedDescription }
  }
  func login() {
    isLoading = true; message = nil
    Task { @MainActor in
      do {
        let payload = ["grant_type": "password", "username": username, "password": password]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let (resp, _) = try await app.api.request(path: "/v1/oauth/token", method: "POST", body: data, headers: ["X-Org-ID": Config.defaultOrgId])
        let obj = try JSONSerialization.jsonObject(with: resp) as? [String: Any]
        if let t = obj?["access_token"] as? String { app.accessToken = t; app.isAuthenticated = true } else { message = "Invalid response" }
      } catch { message = error.localizedDescription }
      isLoading = false
    }
  }
}


