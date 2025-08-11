import SwiftUI

struct Show: Identifiable, Decodable {
  let id: String
  let title: String
  let venue: String
  let nextPerformance: String?
  let posterUrl: String?
  let priceFromMinor: Int?
  let performanceId: String?
}

struct HomeView: View {
  @EnvironmentObject var app: AppState
  @State private var shows: [Show] = []
  @State private var loading = true
  @State private var error: String? = nil
  @State private var selected: Show? = nil
  
  var body: some View {
    NavigationView {
      Group {
        if loading {
          ZStack(alignment: .top) {
            BrandHeader()
            ScrollView {
              VStack(spacing: 16) {
                Color.clear.frame(height: 260)
                ForEach(0..<4, id: \.self) { _ in
                  ShowCardSkeleton().padding(.horizontal, 16)
                }
                Spacer(minLength: 24)
              }
            }
          }
        } else if let e = error {
          VStack(spacing: 12) {
            BrandHeader()
            Image(systemName: "exclamationmark.triangle").font(.system(size: 44)).foregroundColor(.orange)
            Text("Problem loading shows").font(.title3).bold()
            Text(e).font(.footnote).foregroundColor(.secondary).lineLimit(3)
            Button("Try Again", action: load)
            Spacer()
          }.padding()
        } else if shows.isEmpty {
          VStack(spacing: 12) {
            BrandHeader()
            Image(systemName: "ticket").font(.system(size: 44)).foregroundColor(.secondary)
            Text("No shows yet").font(.title3).bold()
            Button("Refresh", action: load)
            Spacer()
          }.padding()
        } else {
          ZStack(alignment: .top) {
            BrandHeader() // stays pinned visually at top
            ScrollView {
              VStack(spacing: 16) {
                Color.clear.frame(height: 260) // spacer under pinned header
              ForEach(shows) { show in
                ShowCard(
                  title: show.title,
                  venue: show.venue,
                  next: show.nextPerformance,
                  imageURL: URL(string: (show.posterUrl?.hasPrefix("http") == true ? show.posterUrl! : (app.api.baseURL.absoluteString + show.posterUrl!))),
                  priceFromMinor: show.priceFromMinor,
                  onTap: { selected = show }
                )
                .padding(.horizontal, 16)
              }
              Spacer(minLength: 24)
              }
            }
          }
        }
      }
      .navigationTitle(" ")
      .navigationBarHidden(true)
    }
    .fullScreenCover(item: $selected) { s in
      SeatmapScreen(show: s).environmentObject(app)
    }
    .onAppear(perform: load)
  }
  private func load() {
    loading = true; error = nil
    Task { @MainActor in
      do {
        let (data, _) = try await app.api.request(path: "/v1/shows", headers: ["X-Org-ID": Config.defaultOrgId])
        if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], let arr = obj["data"] as? [[String: Any]] {
          self.shows = arr.compactMap { d in
            let id = (d["id"] as? String) ?? UUID().uuidString
            let pfInt: Int? = {
              if let n = d["priceFromMinor"] as? NSNumber { return n.intValue }
              if let s = d["priceFromMinor"] as? String, let v = Int(s) { return v }
              if let i = d["priceFromMinor"] as? Int { return i }
              return nil
            }()
            return Show(
              id: id,
              title: (d["title"] as? String) ?? "Show",
              venue: (d["venue"] as? String) ?? "Venue",
              nextPerformance: (d["nextPerformanceAt"] as? String),
              posterUrl: (d["posterUrl"] as? String),
              priceFromMinor: pfInt,
              performanceId: nil
            )
          }
        } else { self.shows = [] }
      } catch { self.error = error.localizedDescription }
      self.loading = false
    }
  }
}


