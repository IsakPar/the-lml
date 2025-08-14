import SwiftUI
import MapKit
import PassKit

// MARK: - Enhanced Success Screen Data Models
struct PaymentSuccessData {
    let orderId: String
    let totalAmount: Int
    let currency: String
    let seatIds: [String]
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
    let onDismiss: () -> Void
    let onSeeMyTickets: () -> Void
    let seatNodes: [SeatNode]? = nil // TODO: Pass from parent if available
    
    private var cleanTicketData: CleanTicketData {
        CleanTicketData(from: successData, seatNodes: seatNodes)
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
                    
                    // LML Glassmorphism Ticket Card
                    LMLTicketCard(ticketData: cleanTicketData)
                    
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
                        onSeeMyTickets: onSeeMyTickets,
                        onBackToShows: onDismiss // Fixed: Now goes to HomeView
                    )
                    
                    // Bottom safe area
                    Color.clear.frame(height: 20)
                }
            }
        }
        .navigationBarHidden(true)
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
                performanceName: "Hamilton",
                performanceDate: "September 15, 2025 at 7:30 PM",
                venueName: "Victoria Palace Theatre",
                venueCoordinates: CLLocationCoordinate2D(latitude: 51.4942, longitude: -0.1358),
                customerEmail: "user@example.com",
                paymentMethod: "Card",
                purchaseDate: "Sep 15, 2025 at 2:45 PM"
            ),
            onDismiss: { print("Back to Shows tapped") },
            onSeeMyTickets: { print("See My Tickets tapped") }
        )
    }
}

