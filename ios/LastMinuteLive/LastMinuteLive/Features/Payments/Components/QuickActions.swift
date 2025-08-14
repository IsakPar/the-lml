import SwiftUI
import PassKit
import MapKit

struct QuickActions: View {
    let ticketData: TicketDisplayData
    let venueCoordinates: CLLocationCoordinate2D?
    let onAddToWallet: () -> Void
    let onShare: () -> Void
    let onDirections: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Action buttons row
            HStack(spacing: 12) {
                // Add to Apple Wallet
                ActionButton(
                    icon: "wallet.pass",
                    title: "Add to Wallet",
                    subtitle: "Apple Wallet",
                    color: .black,
                    action: onAddToWallet
                )
                
                // Share Ticket
                ActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    subtitle: "With friends",
                    color: .blue,
                    action: onShare
                )
                
                // Directions
                ActionButton(
                    icon: "location",
                    title: "Directions",
                    subtitle: "Apple Maps",
                    color: .green,
                    action: onDirections,
                    disabled: venueCoordinates == nil
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    let disabled: Bool
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.action = action
        self.disabled = disabled
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(color.opacity(disabled ? 0.3 : 0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(disabled ? color.opacity(0.5) : color)
                }
                
                // Labels
                VStack(spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(disabled ? .secondary : .primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .scaleEffect(disabled ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: disabled)
        }
        .disabled(disabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Actions Logic
extension QuickActions {
    
    // Check if Apple Wallet is available
    var isWalletAvailable: Bool {
        return PKPassLibrary.isPassLibraryAvailable()
    }
    
    // Format venue coordinates for Apple Maps
    func openDirections() {
        guard let coordinates = venueCoordinates else { return }
        
        let mapItem = MKMapItem(placemark: MKPlacemark(
            coordinate: coordinates,
            addressDictionary: nil
        ))
        mapItem.name = ticketData.venueName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // Create shareable content
    func createShareContent() -> [Any] {
        let shareText = """
        🎫 I'm going to see \(ticketData.eventName) at \(ticketData.venueName)!
        📅 \(ticketData.dateTime)
        🪑 Seats: \(ticketData.seatNumbers.joined(separator: ", "))
        
        Get your tickets on LastMinuteLive! 
        """
        
        return [shareText]
    }
}

// MARK: - Preview
struct QuickActions_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            QuickActions(
                ticketData: TicketDisplayData(
                    eventName: "Hamilton",
                    venueName: "Victoria Palace Theatre",
                    dateTime: "Sept 15, 2025 • 7:30 PM",
                    seatNumbers: ["A-12", "A-13"],
                    qrData: "SAMPLE_QR_DATA",
                    orderReference: "B55C7A...C552"
                ),
                venueCoordinates: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                onAddToWallet: { print("Add to Wallet tapped") },
                onShare: { print("Share tapped") },
                onDirections: { print("Directions tapped") }
            )
            
            // Example with disabled directions
            QuickActions(
                ticketData: TicketDisplayData(
                    eventName: "The Lion King",
                    venueName: "Unknown Venue",
                    dateTime: "Dec 25, 2025 • 2:30 PM",
                    seatNumbers: ["C-5"],
                    qrData: "SAMPLE_QR_DATA_2",
                    orderReference: "A44B66...D441"
                ),
                venueCoordinates: nil, // No coordinates available
                onAddToWallet: { print("Add to Wallet tapped") },
                onShare: { print("Share tapped") },
                onDirections: { print("Directions tapped - should be disabled") }
            )
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
