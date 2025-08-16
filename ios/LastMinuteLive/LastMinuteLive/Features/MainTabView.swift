import SwiftUI

/// Main tab view with proper navigation coordination
/// Manages the core app tabs: Shows, Tickets, Profile
struct MainTabView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @EnvironmentObject var app: AppState
    
    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            // Shows Tab
            NavigationView {
                ShowsListView()
                    .environmentObject(app)
            }
            .tabItem {
                Image(systemName: NavigationCoordinator.AppTab.shows.iconName)
                Text(NavigationCoordinator.AppTab.shows.title)
            }
            .tag(NavigationCoordinator.AppTab.shows)
            
            // Tickets Tab  
            NavigationView {
                TicketsView()
                    .environmentObject(app)
            }
            .tabItem {
                Image(systemName: NavigationCoordinator.AppTab.tickets.iconName)
                Text(NavigationCoordinator.AppTab.tickets.title)
            }
            .tag(NavigationCoordinator.AppTab.tickets)
            
            // Profile Tab
            NavigationView {
                AccountView()
                    .environmentObject(app)
            }
            .tabItem {
                Image(systemName: NavigationCoordinator.AppTab.profile.iconName)
                Text(NavigationCoordinator.AppTab.profile.title)
            }
            .tag(NavigationCoordinator.AppTab.profile)
        }
        .accentColor(StageKit.brandEnd)
        // Shows Tab Sheets
        .sheet(item: $navigationCoordinator.showsPresentedSheet) { sheet in
            switch sheet {
            case .seatmap(let show):
                SeatmapScreen(
                    show: show,
                    navigationCoordinator: navigationCoordinator
                )
                .environmentObject(app)
                
            case .login:
                LoginView()
                    .environmentObject(app)
            }
        }
        // Tickets Tab Sheets
        .sheet(item: $navigationCoordinator.ticketsPresentedSheet) { sheet in
            switch sheet {
            case .qrScanner:
                QRScannerView()
                    .environmentObject(app)
                
            case .ticketDetail(let ticket):
                TicketDetailView(ticket: ticket)
                    .environmentObject(app)
            }
        }
        .environmentObject(navigationCoordinator)
    }
}

// MARK: - Shows List View (Updated to use NavigationCoordinator)

struct ShowsListView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var shows: [Show] = []
    @State private var loading = true
    @State private var error: String?
    
    var body: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            if loading {
                ProgressView()
                    .tint(.white)
            } else if let error = error {
                VStack(spacing: 16) {
                    Text("Error Loading Shows")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(error)
                        .foregroundColor(.white.opacity(0.8))
                    Button("Retry") {
                        loadShows()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(shows) { show in
                            ShowCard(
                                show: show,
                                onTap: {
                                    print("[Shows] 🎭 Show selected: \(show.title)")
                                    navigationCoordinator.presentSeatmap(for: show)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Shows")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadShows()
        }
    }
    
    private func loadShows() {
        loading = true
        error = nil
        
        Task { @MainActor in
            do {
                await app.authenticateForDevelopment()
                let (data, _) = try await app.api.request(path: "/v1/shows")
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let showsArray = json["data"] as? [[String: Any]] {
                    
                    shows = showsArray.compactMap { showDict in
                        guard let id = showDict["id"] as? String,
                              let title = showDict["title"] as? String,
                              let venue = showDict["venue"] as? String else {
                            return nil
                        }
                        
                        return Show(
                            id: id,
                            title: title,
                            venue: venue,
                            nextPerformance: showDict["nextPerformanceAt"] as? String,
                            posterUrl: showDict["posterUrl"] as? String,
                            priceFromMinor: showDict["priceFromMinor"] as? Int ?? 2500
                        )
                    }
                }
                
                loading = false
            } catch {
                self.error = error.localizedDescription
                loading = false
            }
        }
    }
}

// MARK: - Show Card Component

struct ShowCard: View {
    let show: Show
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Show poster/image placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(StageKit.brandGradient)
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "theatermasks.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                            Text(show.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(show.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(show.venue)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let nextPerformance = show.nextPerformance {
                        Text(formatDate(nextPerformance))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Text("From £\(Double(show.priceFromMinor) / 100, specifier: "%.0f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(StageKit.brandEnd)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(StageKit.hairline, lineWidth: 1)
                )
        )
    }
    
    private func formatDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return isoDate
    }
}

// MARK: - Placeholder Views (to be implemented in Phase 3)

struct TicketsView: View {
    var body: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.3))
                
                Text("My Tickets")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your purchased tickets will appear here")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("Coming in Phase 3: Ticket Storage & Offline Access")
                    .font(.caption)
                    .foregroundColor(StageKit.brandEnd)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("My Tickets")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct QRScannerView: View {
    var body: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            Text("QR Scanner - Coming Soon!")
                .font(.title2)
                .foregroundColor(.white)
        }
        .navigationTitle("Scan QR Code")
    }
}

struct TicketDetailView: View {
    let ticket: TicketData
    
    var body: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            Text("Ticket Detail - Coming Soon!")
                .font(.title2)
                .foregroundColor(.white)
        }
        .navigationTitle("Ticket Details")
    }
}

// MARK: - Preview

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppState())
    }
}
