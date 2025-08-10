import SwiftUI

struct SeatmapView: View {
  let seatmapId: String
  @EnvironmentObject var appState: AppState
  @State private var seatmap: [String: Any]? = nil
  @State private var error: String? = nil
  @State private var etag: String? = nil

  var body: some View {
    VStack(alignment: .leading) {
      if let e = error { Text(e).foregroundColor(.red) }
      if let m = seatmap {
        Text(m["name"] as? String ?? "Seatmap").font(.headline)
        Text("Version: \(m["version"] as? Int ?? 0)").font(.footnote)
      } else { ProgressView() }
      Spacer()
    }
    .padding()
    .navigationTitle("Seatmap")
    .task { await fetchSeatmap() }
  }

  func fetchSeatmap() async {
    guard let token = appState.accessToken else { return }
    let base = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000")!
    let client = ApiClient(baseURL: base, accessToken: token, orgId: "00000000-0000-0000-0000-000000000001")
    do {
      var path = "/v1/seatmaps/" + seatmapId
      let (data, http) = try await client.request(path: path)
      if let tag = http.value(forHTTPHeaderField: "ETag") { self.etag = tag }
      if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] { self.seatmap = obj }
    } catch let e as ApiError { self.error = e.localizedDescription }
    catch { self.error = "Unexpected error" }
  }
}


