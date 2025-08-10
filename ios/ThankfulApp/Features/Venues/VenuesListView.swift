import SwiftUI

struct Venue: Identifiable, Decodable {
  let id: String
  let name: String
}

struct VenuesResponse: Decodable { let data: [Venue] }

struct VenuesListView: View {
  @EnvironmentObject var appState: AppState
  @State private var venues: [Venue] = []
  @State private var error: String? = nil
  @State private var loading = false

  var body: some View {
    VStack(alignment: .leading) {
      if loading { ProgressView().padding() }
      if let e = error { Text(e).foregroundColor(.red).padding(.horizontal) }
      List(venues) { v in
        Text(v.name)
      }
      .listStyle(.plain)
      .refreshable { await fetchVenues() }
    }
    .navigationTitle("Venues")
    .task { await fetchVenues() }
  }

  func fetchVenues() async {
    guard let token = appState.accessToken else { return }
    loading = true
    error = nil
    let base = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:3000")!
    let client = ApiClient(baseURL: base, accessToken: token, orgId: "00000000-0000-0000-0000-000000000001")
    do {
      let (data, _) = try await client.request(path: "/v1/venues")
      let resp = try JSONDecoder().decode(VenuesResponse.self, from: data)
      self.venues = resp.data
    } catch let e as ApiError {
      self.error = e.localizedDescription
    } catch { self.error = "Unexpected error" }
    loading = false
  }
}

struct VenuesListView_Previews: PreviewProvider {
  static var previews: some View { VenuesListView().environmentObject(AppState()) }
}


