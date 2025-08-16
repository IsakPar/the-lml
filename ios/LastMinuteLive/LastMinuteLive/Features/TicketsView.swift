import SwiftUI

struct TicketsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var showingTicketDetail: TicketDisplayModel?
    @State private var isLoadingTickets = false
    
    // Computed property to get tickets from shared service
    private var tickets: [TicketDisplayModel] {
        app.ticketStorageService?.tickets ?? []
    }
    
    private var isLoading: Bool {
        isLoadingTickets || (app.ticketStorageService?.isLoading ?? false)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                StageKit.bgGradient.ignoresSafeArea()
                
                Group {
                    if app.isAuthenticated {
                        if isLoading {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                                Text("Loading your tickets...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        } else if tickets.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("No Tickets Yet")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Your purchased tickets will appear here.\nBuy a ticket to see it stored offline!")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                // Action button to go to shows
                                Button(action: {
                                    navigationCoordinator.navigateToShows()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "theatermasks")
                                        Text("Browse Shows")
                                    }
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(StageKit.brandGradient)
                                    .cornerRadius(12)
                                    .shadow(color: StageKit.brandEnd.opacity(0.4), radius: 12, x: 0, y: 6)
                                }
                                .padding(.top, 8)
                                
                                Spacer()
                            }
                            .padding()
                        } else {
                            // Tickets list
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(tickets, id: \.id) { ticket in
                                        ModernTicketRow(
                                            ticket: ticket,
                                            onTap: {
                                                showingTicketDetail = ticket
                                            }
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                    
                                    // Bottom spacing
                                    Color.clear.frame(height: 24)
                                }
                                .padding(.top, 16)
                            }
                        }
                    } else {
                        // Not authenticated state
                        VStack(spacing: 20) {
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text("Sign In to Access Tickets")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Create an account or sign in to securely store your tickets in the app for offline access on show day.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button(action: {
                                navigationCoordinator.presentLogin()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.badge.key")
                                    Text("Sign In or Create Account")
                                }
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 24)
                                .background(StageKit.brandGradient)
                                .cornerRadius(16)
                                .shadow(color: StageKit.brandEnd.opacity(0.4), radius: 16, x: 0, y: 8)
                            }
                            .padding(.top, 8)
                            
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Tickets")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                setupTicketStorage()
            }
            .refreshable {
                await refreshTickets()
            }
        }
        .sheet(item: $showingTicketDetail) { ticket in
            TicketDetailView(ticket: ticket)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupTicketStorage() {
        // Use the shared ticket storage service from AppState
        guard let sharedTicketService = app.ticketStorageService else {
            print("[TicketsView] ❌ No shared ticket storage service available")
            return
        }
        
        // Load tickets for current user
        Task {
            isLoadingTickets = true
            await sharedTicketService.loadTicketsForCurrentUser()
            await MainActor.run {
                isLoadingTickets = false
            }
            print("[TicketsView] ✅ Loaded \(sharedTicketService.tickets.count) tickets from shared service")
        }
    }
    
    private func refreshTickets() async {
        guard let sharedTicketService = app.ticketStorageService else {
            print("[TicketsView] ❌ No shared ticket storage service available for refresh")
            return
        }
        
        await MainActor.run {
            isLoadingTickets = true
        }
        
        await sharedTicketService.refreshTickets()
        
        await MainActor.run {
            isLoadingTickets = false
        }
        
        print("[TicketsView] 🔄 Refreshed tickets from shared service")
    }
}


