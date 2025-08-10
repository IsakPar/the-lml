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
    let base = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000")!
    let client = ApiClient(baseURL: base, accessToken: token, orgId: "00000000-0000-0000-0000-000000000001")
    Task { @MainActor in
      do {
        let (data, _) = try await client.request(path: "/v1/users/me")
        if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] { self.me = obj }
      } catch let e as ApiError { self.error = e.localizedDescription }
      catch { self.error = "Unexpected error" }
    }
  }
}

struct MeView_Previews: PreviewProvider {
  static var previews: some View { MeView().environmentObject(AppState()) }
}


