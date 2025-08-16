import SwiftUI
import MapKit
import PassKit

// MARK: - Enhanced Success Screen Data Models
struct PaymentSuccessData {
    let orderId: String
    let totalAmount: Int
    let currency: String
    let seatIds: [String]
    let seatNodes: [SeatNode]? // NEW: Actual seat node data for proper formatting
    let performanceName: String
    let performanceDate: String
    let venueName: String
    let venueCoordinates: CLLocationCoordinate2D?
    let customerEmail: String?
    let paymentMethod: String
    let purchaseDate: String
}

// MARK: - Clean Payment Success Screen
struct PaymentSuccessScreen: View {
    let successData: PaymentSuccessData
    let navigationCoordinator: NavigationCoordinator
    
    // Environment and state for ticket storage
    @EnvironmentObject var app: AppState
    @State private var ticketStorageComplete = false
    
    init(successData: PaymentSuccessData, navigationCoordinator: NavigationCoordinator) {
        self.successData = successData
        self.navigationCoordinator = navigationCoordinator
    }
    
    private var cleanTicketData: CleanTicketData {
        CleanTicketData(from: successData, seatNodes: successData.seatNodes)
    }
    
    var body: some View {
        ZStack {
            // LML Background
            StageKit.bgGradient.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Clean Success Header (no emojis)
                    CleanSuccessHeader(
                        eventName: successData.performanceName,
                        seatCount: successData.seatIds.count,
                        eventDate: extractCleanDate(from: successData.performanceDate)
                    )
                    
                    // Swipeable Ticket Cards (shows individual tickets for multiple seats)
                    SwipeableTickets(
                        cleanTicketData: cleanTicketData,
                        seatNodes: successData.seatNodes
                    )
                    
                    // Native Action Buttons
                    NativeActionButtons(
                        ticketData: cleanTicketData,
                        venueCoordinates: successData.venueCoordinates,
                        onAddToWallet: handleAddToWallet,
                        onShare: handleShare,
                        onDirections: handleDirections
                    )
                    
                    // Simple Navigation
                    SimpleNavigation(
                        onSeeMyTickets: {
                            print("[Success] 🎫 See My Tickets tapped - navigating to tickets tab")
                            navigationCoordinator.navigateToTickets()
                        },
                        onBackToShows: {
                            print("[Success] 🏠 Back to Shows tapped - navigating to shows tab")
                            navigationCoordinator.navigateToShows()
                        }
                    )
                    
                    // Bottom safe area
                    Color.clear.frame(height: 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Automatically store ticket when success screen appears
            Task {
                await storeTicketFromPayment()
            }
        }
    }
    
    // MARK: - Ticket Storage
    
    /// Store the ticket from payment success data
    private func storeTicketFromPayment() async {
        guard !ticketStorageComplete else { return }
        
        print("[PaymentSuccess] 🎫 Storing ticket for order: \(successData.orderId)")
        print("[PaymentSuccess] 🔍 Debug info:")
        print("[PaymentSuccess] - Customer email: \(successData.customerEmail ?? "nil")")
        print("[PaymentSuccess] - App authenticated: \(app.isAuthenticated)")
        print("[PaymentSuccess] - App userEmail: \(app.userEmail ?? "nil")")
        
        // Use the shared ticket storage service from AppState
        guard let sharedTicketService = app.ticketStorageService else {
            print("[PaymentSuccess] ❌ No ticket storage service available")
            return
        }
        
        let success = await sharedTicketService.storeTicketFromPayment(successData)
        
        if success {
            ticketStorageComplete = true
            print("[PaymentSuccess] ✅ Ticket stored successfully in shared service")
            print("[PaymentSuccess] 📊 Tickets in service: \(sharedTicketService.tickets.count)")
        } else {
            print("[PaymentSuccess] ❌ Failed to store ticket")
            if let error = sharedTicketService.lastError {
                print("[PaymentSuccess] Error details: \(error)")
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleAddToWallet() {
        print("[Success] 🏦 Add to Wallet tapped for order: \(successData.orderId)")
        
        // Check if Wallet is available
        if PKPassLibrary.isPassLibraryAvailable() {
            // TODO: Generate .pkpass file from backend
            // This would call something like: POST /v1/orders/{id}/wallet-pass
            print("[Success] 📱 Wallet is available - generating pass...")
        } else {
            print("[Success] ❌ Apple Wallet not available")
        }
    }
    
    private func handleShare() {
        print("[Success] 📤 Share tapped")
        // The sharing is handled by NativeActionButtons component
    }
    
    private func handleDirections() {
        guard let coordinates = successData.venueCoordinates else {
            print("[Success] ❌ No coordinates available for venue")
            return
        }
        
        print("[Success] 🗺️ Opening Apple Maps for \(successData.venueName)")
        
        let mapItem = MKMapItem(placemark: MKPlacemark(
            coordinate: coordinates,
            addressDictionary: nil
        ))
        mapItem.name = successData.venueName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // MARK: - Helper Functions
    
    private func extractCleanDate(from dateString: String) -> String {
        // Extract just the date part: "Sept 15, 2025 • 7:30 PM" -> "Sept 15"
        let cleanDate = DataFormatters.formatPerformanceDateTime(dateString)
        return cleanDate.components(separatedBy: " • ").first ?? dateString
    }
}

// ShareSheet is now defined in NativeActionButtons.swift

// MARK: - Preview
struct PaymentSuccessScreen_Previews: PreviewProvider {
    static var previews: some View {
        PaymentSuccessScreen(
            successData: PaymentSuccessData(
                orderId: "b55c7a7f-c552-4ce0-aba0-e4f4a7414e65",
                totalAmount: 7500,  // £75.00
                currency: "GBP",
                seatIds: ["8a523482-ddc9-4ee6-99c3", "396c72f1-e153-478c"],
                seatNodes: nil, // TODO: Add sample SeatNode data for preview
                performanceName: "Hamilton",
                performanceDate: "September 15, 2025 at 7:30 PM",
                venueName: "Victoria Palace Theatre",
                venueCoordinates: CLLocationCoordinate2D(latitude: 51.4942, longitude: -0.1358),
                customerEmail: "user@example.com",
                paymentMethod: "Card",
                purchaseDate: "Sep 15, 2025 at 2:45 PM"
            ),
            navigationCoordinator: NavigationCoordinator()
        )
    }
}

