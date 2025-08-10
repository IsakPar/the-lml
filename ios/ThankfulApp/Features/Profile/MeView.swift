import SwiftUI

struct MeView: View {
  @EnvironmentObject var appState: AppState
  @State private var me: [String: Any]? = nil
  @State private var error: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Account").font(.title2).bold()
      if let m = me {
        Text("User ID: \(m["user_id"] as? String ?? "-")")
        Text("Org: \(m["org_id"] as? String ?? "-")")
        Text("Trace: \(m["trace_id"] as? String ?? "-")
")
      } else if let e = error { Text(e).foregroundColor(.red) } else { ProgressView() }
      Button("Sign out") { appState.isAuthenticated = false; appState.accessToken = nil }
        .padding(.top, 16)
      Spacer()
    }
    .padding()
    .onAppear(perform: load)
  }

  func load() {
    guard let token = appState.accessToken else { return }
    guard let url = URL(string: (ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000") + "/v1/users/me") else { return }
    var req = URLRequest(url: url)
    req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.addValue("00000000-0000-0000-0000-000000000001", forHTTPHeaderField: "X-Org-ID")
    let task = URLSession.shared.dataTask(with: req) { data, resp, _ in
      DispatchQueue.main.async {
        guard let http = resp as? HTTPURLResponse, let data = data else { self.error = "Network error"; return }
        if http.statusCode == 200, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          self.me = obj
        } else {
          self.error = "Failed: \(http.statusCode)"
        }
      }
    }
    task.resume()
  }
}

struct MeView_Previews: PreviewProvider {
  static var previews: some View { MeView().environmentObject(AppState()) }
}


