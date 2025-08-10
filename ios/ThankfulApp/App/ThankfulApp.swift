import SwiftUI

@main
struct ThankfulApp: App {
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      NavigationView {
        if appState.isAuthenticated {
          MeView()
            .environmentObject(appState)
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


