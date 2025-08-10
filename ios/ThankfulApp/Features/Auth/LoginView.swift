import SwiftUI

struct LoginView: View {
  @EnvironmentObject var appState: AppState
  @State private var username: String = ""
  @State private var password: String = ""
  @State private var message: String? = nil
  @State private var isLoading = false

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
      Spacer()
    }
    .padding()
  }

  func login() {
    guard let url = URL(string: (ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000") + "/v1/oauth/token") else { return }
    isLoading = true
    message = nil
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = ["grant_type": "password", "username": username, "password": password]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    let task = URLSession.shared.dataTask(with: req) { data, resp, _ in
      DispatchQueue.main.async {
        self.isLoading = false
        guard let http = resp as? HTTPURLResponse, let data = data else { self.message = "Network error"; return }
        if http.statusCode == 200, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let token = obj["access_token"] as? String {
          self.appState.accessToken = token
          self.appState.isAuthenticated = true
        } else {
          self.message = "Login failed (\(http.statusCode))"
        }
      }
    }
    task.resume()
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View { LoginView().environmentObject(AppState()) }
}


