import SwiftUI
import LocalAuthentication

@main
struct ThankfulApp: App {
  @StateObject private var appState = AppState()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      NavigationView {
        if appState.isAuthenticated {
          TabView {
            VenuesListView()
              .tabItem { Label("Venues", systemImage: "building.2") }
              .environmentObject(appState)
            ScannerScreen()
              .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
              .environmentObject(appState)
            NavigationView { TicketsView() }
              .tabItem { Label("Tickets", systemImage: "ticket") }
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
      .onChange(of: scenePhase) { phase in
        if phase == .active { appState.verifierStartRefresh() }
      }
    }
  }
}

final class AppState: ObservableObject {
  @Published var isAuthenticated: Bool = false
  @Published var accessToken: String? = nil
  let api = ApiClient(baseURL: URL(string: Config.apiBaseUrl)!)
  lazy var verifier = VerifierService(api: api)

  func verifierStartRefresh() {
    Task { try? await verifier.refreshJwks() }
    verifier.startAutoRefresh()
  }

  func enableBiometricLoginIfAvailable(completion: @escaping (Bool) -> Void) {
    let ctx = LAContext()
    var err: NSError?
    if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) {
      ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Thankful") { ok, _ in
        DispatchQueue.main.async { completion(ok) }
      }
    } else {
      completion(false)
    }
  }
}


