import SwiftUI
import PassKit
import MapKit

struct NativeActionButtons: View {
    let ticketData: CleanTicketData
    let venueCoordinates: CLLocationCoordinate2D?
    let onAddToWallet: () -> Void
    let onShare: () -> Void
    let onDirections: () -> Void
    
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // Simple email confirmation
            EmailConfirmationBanner()
            
            // Native action buttons
            HStack(spacing: 12) {
                // Add to Apple Wallet - Native SF Symbol
                if PKPassLibrary.isPassLibraryAvailable() {
                    Button(action: onAddToWallet) {
                        Label("Add to Wallet", systemImage: "plus.rectangle.on.folder.fill")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(NativeActionButtonStyle(color: .black, isDisabled: false))
                } else {
                    Button(action: onAddToWallet) {
                        Label("Add to Wallet", systemImage: "plus.rectangle.on.folder")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(NativeActionButtonStyle(color: .gray, isDisabled: true))
                }
                
                // Share - Native share button
                Button(action: handleShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .buttonStyle(NativeActionButtonStyle(color: StageKit.brandEnd, isDisabled: false))
                
                // Directions - Native maps button with proper SF Symbol
                if venueCoordinates != nil {
                    Button(action: onDirections) {
                        Label("Directions", systemImage: "map.fill")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(NativeActionButtonStyle(color: StageKit.success, isDisabled: false))
                } else {
                    Button(action: onDirections) {
                        Label("Directions", systemImage: "map")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(NativeActionButtonStyle(color: .gray, isDisabled: true))
                }
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    private func handleShare() {
        let shareText = """
        I'm going to see \(ticketData.eventName) at \(ticketData.venueName)!
        📅 \(ticketData.cleanDateTime)
        🪑 Seats: \(ticketData.readableSeats)
        
        Get your tickets on LastMinuteLive! 
        """
        
        shareItems = [shareText]
        showShareSheet = true
        onShare() // Call the callback too
    }
}

// MARK: - Email Confirmation Banner
struct EmailConfirmationBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 16))
                .foregroundColor(StageKit.brandEnd)
            
            Text("Receipt emailed to you")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(StageKit.success)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(StageKit.brandEnd.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Native Action Button Style
struct NativeActionButtonStyle: ButtonStyle {
    let color: Color
    let isDisabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isDisabled 
                            ? Color.gray.opacity(0.3)
                            : (configuration.isPressed ? color.opacity(0.8) : color)
                    )
            )
            .foregroundColor(isDisabled ? .gray : .white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .disabled(isDisabled)
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
struct NativeActionButtons_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 30) {
                NativeActionButtons(
                    ticketData: CleanTicketData(
                        from: PaymentSuccessData(
                            orderId: "b55c7a7f-c552-4ce0-aba0-e4f4a7414e65",
                            totalAmount: 7500,
                            currency: "GBP",
                            seatIds: ["8a523482-ddc9-4ee6", "396c72f1-e153"],
                            seatNodes: [
                                SeatNode(id: "8a523482-ddc9-4ee6", sectionId: "orchestra", x: 100, y: 200, w: 20, h: 20, colorHex: nil, priceLevelId: "premium", attrs: SeatAttributes(rawValue: 0), row: "A", number: "12"),
                                SeatNode(id: "396c72f1-e153", sectionId: "orchestra", x: 120, y: 200, w: 20, h: 20, colorHex: nil, priceLevelId: "premium", attrs: SeatAttributes(rawValue: 0), row: "A", number: "13")
                            ],
                            performanceName: "Hamilton",
                            performanceDate: "September 15, 2025 at 7:30 PM",
                            venueName: "Victoria Palace Theatre",
                            venueCoordinates: CLLocationCoordinate2D(latitude: 51.4942, longitude: -0.1358),
                            customerEmail: "user@example.com",
                            paymentMethod: "Card",
                            purchaseDate: "Sep 15, 2025 at 2:45 PM"
                        )
                    ),
                    venueCoordinates: CLLocationCoordinate2D(latitude: 51.4942, longitude: -0.1358),
                    onAddToWallet: { print("Add to Wallet tapped") },
                    onShare: { print("Share tapped") },
                    onDirections: { print("Directions tapped") }
                )
                
                // Example with disabled Maps
                NativeActionButtons(
                    ticketData: CleanTicketData(
                        from: PaymentSuccessData(
                            orderId: "a44b66c2-d441-3bd9-8fe2-c8e5a6d7b9f1",
                            totalAmount: 15000,
                            currency: "GBP",
                            seatIds: ["uuid1", "uuid2", "uuid3", "uuid4"],
                            seatNodes: [
                                SeatNode(id: "uuid1", sectionId: "balcony", x: 50, y: 50, w: 16, h: 16, colorHex: nil, priceLevelId: "budget", attrs: SeatAttributes(rawValue: 0), row: "F", number: "10"),
                                SeatNode(id: "uuid2", sectionId: "balcony", x: 66, y: 50, w: 16, h: 16, colorHex: nil, priceLevelId: "budget", attrs: SeatAttributes(rawValue: 0), row: "F", number: "11"),
                                SeatNode(id: "uuid3", sectionId: "balcony", x: 82, y: 50, w: 16, h: 16, colorHex: nil, priceLevelId: "budget", attrs: SeatAttributes(rawValue: 0), row: "F", number: "12"),
                                SeatNode(id: "uuid4", sectionId: "balcony", x: 98, y: 50, w: 16, h: 16, colorHex: nil, priceLevelId: "budget", attrs: SeatAttributes(rawValue: 0), row: "F", number: "13")
                            ],
                            performanceName: "The Lion King",
                            performanceDate: "December 25, 2025 at 2:30 PM",
                            venueName: "Unknown Venue",
                            venueCoordinates: nil,
                            customerEmail: nil,
                            paymentMethod: "Apple Pay",
                            purchaseDate: "Dec 20, 2025 at 11:30 AM"
                        )
                    ),
                    venueCoordinates: nil,
                    onAddToWallet: { print("Add to Wallet tapped") },
                    onShare: { print("Share tapped") },
                    onDirections: { print("Directions tapped - should be disabled") }
                )
            }
            .padding()
        }
    }
}
