import SwiftUI

struct AvailabilitySnapshot: Decodable {
  let performance_id: String
  let seatmap_id: String
  let seats: [Seat]
  struct Seat: Decodable { let seat_id: String; let status: String }
}

struct AvailabilityView: View {
  let perfId: String
  let seatmapId: String
  @EnvironmentObject var appState: AppState
  @State private var snapshot: AvailabilitySnapshot?
  @State private var error: String?

  var body: some View {
    VStack(alignment: .leading) {
      if let e = error { Text(e).foregroundColor(.red) }
      if let s = snapshot {
        Text("Held: \(s.seats.filter{ $0.status == \"held\" }.count)")
        Text("Available: \(s.seats.filter{ $0.status == \"available\" }.count)")
      } else { ProgressView() }
      Spacer()
    }
    .padding()
    .navigationTitle("Availability")
    .task { await fetch() }
  }

  func fetch() async {
    guard let token = appState.accessToken else { return }
    let base = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000")!
    let client = ApiClient(baseURL: base, accessToken: token, orgId: "00000000-0000-0000-0000-000000000001")
    do {
      let (data, _) = try await client.request(path: "/v1/performances/\(perfId)/availability?seatmap_id=\(seatmapId)")
      let s = try JSONDecoder().decode(AvailabilitySnapshot.self, from: data)
      self.snapshot = s
    } catch let e as ApiError { self.error = e.localizedDescription }
    catch { self.error = "Unexpected error" }
  }
}


