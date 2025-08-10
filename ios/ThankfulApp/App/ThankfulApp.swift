import SwiftUI

@main
struct ThankfulApp: App {
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      NavigationView {
        if appState.isAuthenticated {
          TabView {
            VenuesListView()
              .tabItem { Label("Venues", systemImage: "building.2") }
              .environmentObject(appState)
            MeView()
              .tabItem { Label("Me", systemImage: "person.circle") }
              .environmentObject(appState)
          }
        } else {
          LoginView()
            .environmentObject(appState)
        }
      }
    }
  }
}

final class AppState: ObservableObject {
  @Published var isAuthenticated: Bool = false
  @Published var accessToken: String? = nil
}


