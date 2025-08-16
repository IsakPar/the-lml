import SwiftUI

/// Modern ticket row component with glassmorphism design
/// Shows ticket information in a clean, accessible format
struct ModernTicketRow: View {
    let ticket: TicketDisplayModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Event Icon & Status
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(StageKit.brandGradient)
                            .frame(width: 50, height: 50)
                        
                        if ticket.isScanned {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "ticket.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Sync status indicator
                    syncStatusIndicator
                }
                
                // Ticket Information
                VStack(alignment: .leading, spacing: 6) {
                    // Event Name
                    Text(ticket.eventName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Venue & Seat
                    HStack(spacing: 8) {
                        Label(ticket.venueName, systemImage: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(ticket.seatInfo)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    
                    // Date & Time
                    Text(ticket.shortEventDate)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Purchase Info
                    HStack {
                        Text("Purchased: \(formatPurchaseDate(ticket.purchaseDate))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text(ticket.displayTotalAmount)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
    
    // MARK: - Sync Status Indicator
    
    @ViewBuilder
    private var syncStatusIndicator: some View {
        switch ticket.syncStatus {
        case .synced:
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .opacity(0.8)
        case .pending:
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .opacity(0.8)
        case .failed:
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(0.8)
        case .offline:
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .opacity(0.8)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatPurchaseDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct ModernTicketRow_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 16) {
                ModernTicketRow(
                    ticket: TicketDisplayModel(
                        id: UUID(),
                        orderId: "ORDER-12345",
                        eventName: "Hamilton",
                        venueName: "Theatre Royal Drury Lane",
                        eventDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                        seatInfo: "Row D, Seat 15",
                        qrData: "sample-qr-data",
                        purchaseDate: Date(),
                        totalAmount: 75.00,
                        currency: "GBP",
                        customerEmail: "user@example.com",
                        isScanned: false,
                        syncStatus: .synced
                    ),
                    onTap: {
                        print("Ticket tapped")
                    }
                )
                .padding(.horizontal, 16)
                
                ModernTicketRow(
                    ticket: TicketDisplayModel(
                        id: UUID(),
                        orderId: "ORDER-67890",
                        eventName: "The Lion King",
                        venueName: "Lyceum Theatre",
                        eventDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                        seatInfo: "Row J, Seats 8-9",
                        qrData: "sample-qr-data-2",
                        purchaseDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                        totalAmount: 150.00,
                        currency: "GBP",
                        customerEmail: "user@example.com",
                        isScanned: true,
                        syncStatus: .synced
                    ),
                    onTap: {
                        print("Ticket 2 tapped")
                    }
                )
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.top, 20)
        }
    }
}
