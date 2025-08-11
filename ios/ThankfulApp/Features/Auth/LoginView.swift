import SwiftUI
import LocalAuthentication

struct LoginView: View {
  @EnvironmentObject var appState: AppState
  @State private var username: String = ""
  @State private var password: String = ""
  @State private var message: String? = nil
  @State private var isLoading = false
  @State private var biometricsAvailable = false

  var body: some View {
    VStack(spacing: 16) {
      Text("Thankful")
        .font(.largeTitle).bold()
      TextField("Email", text: $username)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .textFieldStyle(.roundedBorder)
      SecureField("Password", text: $password)
        .textFieldStyle(.roundedBorder)
      if let msg = message { Text(msg).foregroundColor(.red).font(.footnote) }
      Button(action: login) {
        if isLoading { ProgressView() } else { Text("Sign in") }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isLoading || username.isEmpty || password.isEmpty)
      if biometricsAvailable {
        Button("Use Face ID / Touch ID") { biometricLogin() }.buttonStyle(.bordered)
      }
      Spacer()
    }
    .padding()
  }

  func login() {
    isLoading = true
    message = nil
    Task { @MainActor in
      do {
        let base = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000")!
        let client = ApiClient(baseURL: base)
        let payload = ["grant_type": "password", "username": username, "password": password]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let (resp, _) = try await client.request(path: "/v1/oauth/token", method: "POST", body: data)
        let obj = try JSONSerialization.jsonObject(with: resp) as? [String: Any]
        let token = obj?["access_token"] as? String
        if let t = token {
          _ = KeychainHelper.save(key: "access_token", data: Data(t.utf8))
           self.appState.accessToken = t
           self.appState.isAuthenticated = true
           self.appState.verifierStartRefresh()
        } else { self.message = "Invalid response" }
      } catch let e as ApiError {
        self.message = e.localizedDescription
      } catch {
        self.message = "Unexpected error"
      }
      self.isLoading = false
    }
  }

  func biometricLogin() {
    let ctx = LAContext()
    var err: NSError?
    if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) {
      ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Thankful") { ok, _ in
        DispatchQueue.main.async {
          if ok { self.appState.isAuthenticated = true } else { self.message = "Biometric failed" }
        }
      }
    } else {
      self.message = "Biometrics unavailable"
    }
  }
  init() {
    let ctx = LAContext()
    var err: NSError?
    _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    _biometricsAvailable = State(initialValue: err == nil)
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View { LoginView().environmentObject(AppState()) }
}


