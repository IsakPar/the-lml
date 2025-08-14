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
    
    // Computed properties for components
    var ticketData: TicketDisplayData {
        TicketDisplayData(
            eventName: performanceName,
            venueName: venueName,
            dateTime: performanceDate,
            seatNumbers: seatIds,
            qrData: TicketDisplayData.createQRData(
                orderId: orderId,
                eventName: performanceName,
                date: extractDateForQR(from: performanceDate),
                seats: seatIds
            ),
            orderReference: formatOrderReference(orderId)
        )
    }
    
    var orderSummary: OrderSummaryData {
        OrderSummaryData(
            fullOrderId: orderId,
            totalAmount: totalAmount,
            seatCount: seatIds.count,
            seatNumbers: seatIds,
            paymentMethod: paymentMethod,
            purchaseDate: purchaseDate,
            customerEmail: customerEmail
        )
    }
    
    private func extractDateForQR(from dateString: String) -> String {
        // Simple date extraction for QR code
        return dateString.components(separatedBy: " ").first ?? dateString
    }
    
    private func formatOrderReference(_ fullId: String) -> String {
        // Format: "B55C7A...C552"
        if fullId.count > 12 {
            let prefix = String(fullId.prefix(6))
            let suffix = String(fullId.suffix(4))
            return "\(prefix)...\(suffix)".uppercased()
        }
        return fullId.uppercased()
    }
}

// MARK: - Premium Payment Success Screen
struct PaymentSuccessScreen: View {
    let successData: PaymentSuccessData
    let onDismiss: () -> Void
    let onSeeMyTickets: () -> Void
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Premium Success Header with Animation
                    SuccessHeader(
                        eventName: successData.performanceName,
                        seatCount: successData.seatIds.count,
                        eventDate: extractDateOnly(from: successData.performanceDate)
                    )
                    .padding(.top, 20)
                    
                    // Hero Ticket Card with QR Code
                    TicketCard(ticketData: successData.ticketData)
                        .padding(.vertical, 8)
                    
                    // Quick Actions Row
                    QuickActions(
                        ticketData: successData.ticketData,
                        venueCoordinates: successData.venueCoordinates,
                        onAddToWallet: handleAddToWallet,
                        onShare: handleShareTicket,
                        onDirections: handleDirections
                    )
                    
                    // Order Summary (Expandable)
                    OrderDetailsView(orderData: successData.orderSummary)
                    
                    // Bottom Navigation Actions
                    VStack(spacing: 12) {
                        // Primary Action - Navigate to Tickets Tab
                        Button(action: onSeeMyTickets) {
                            HStack(spacing: 8) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 16, weight: .medium))
                                Text("See My Tickets")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue,
                                        Color.blue.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        // Secondary Action
                        Button(action: onDismiss) {
                            Text("Back to Shows")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // Bottom padding
                    Spacer(minLength: 40)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGray6).opacity(0.3),
                        Color(.systemBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Prevent split view on iPad
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleAddToWallet() {
        print("[Success] Add to Wallet tapped for order: \(successData.orderId)")
        // TODO: Implement Apple Wallet pass generation
        // This would typically call a backend endpoint to generate a .pkpass file
    }
    
    private func handleShareTicket() {
        print("[Success] Share ticket tapped")
        
        // Create shareable content
        let shareText = """
        🎫 I'm going to see \(successData.performanceName) at \(successData.venueName)!
        📅 \(successData.performanceDate)
        🪑 Seats: \(successData.seatIds.joined(separator: ", "))
        
        Get your tickets on LastMinuteLive! 
        """
        
        shareItems = [shareText]
        showShareSheet = true
    }
    
    private func handleDirections() {
        guard let coordinates = successData.venueCoordinates else {
            print("[Success] No coordinates available for venue")
            return
        }
        
        print("[Success] Opening directions to venue")
        
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
    
    private func extractDateOnly(from dateString: String) -> String {
        // Extract date part from "Sept 15, 2025 • 7:30 PM" -> "Sept 15, 2025"
        return dateString.components(separatedBy: " • ").first ?? dateString
    }
}

// MARK: - ShareSheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview
struct PaymentSuccessScreen_Previews: PreviewProvider {
    static var previews: some View {
        PaymentSuccessScreen(
            successData: PaymentSuccessData(
                orderId: "b55c7a7f-c552-4ce0-aba0-e4f4a7414e65",
                totalAmount: 7500,  // £75.00
                currency: "GBP",
                seatIds: ["A-12", "A-13"],
                performanceName: "Hamilton",
                performanceDate: "September 15, 2025 • 7:30 PM",
                venueName: "Victoria Palace Theatre",
                venueCoordinates: CLLocationCoordinate2D(latitude: 51.4942, longitude: -0.1358), // Victoria Palace Theatre
                customerEmail: "user@example.com",
                paymentMethod: "•••• 4242 (Visa)",
                purchaseDate: "Sep 15, 2025 at 2:45 PM"
            ),
            onDismiss: { print("Dismiss tapped") },
            onSeeMyTickets: { print("See My Tickets tapped") }
        )
    }
}
