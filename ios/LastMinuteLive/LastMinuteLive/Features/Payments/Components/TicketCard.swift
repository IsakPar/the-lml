import SwiftUI

struct TicketCard: View {
    let ticketData: TicketDisplayData
    
    var body: some View {
        VStack(spacing: 0) {
            // Main ticket body
            VStack(spacing: 16) {
                // Ticket header with event info
                VStack(spacing: 8) {
                    // Venue/Show name
                    Text(ticketData.eventName.uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // Venue name
                    Text(ticketData.venueName)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Event details row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATE & TIME")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(ticketData.dateTime)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("SEATS")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(formatSeats(ticketData.seatNumbers))
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 20)
                
                // QR Code
                TicketQRCodeView(
                    data: ticketData.qrData,
                    size: 160,
                    backgroundColor: .white,
                    foregroundColor: .black
                )
                .padding(.vertical, 8)
                
                // Order ID and branding
                VStack(spacing: 6) {
                    Text("Order #\(ticketData.orderReference)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Powered by LastMinuteLive")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 20)
            }
            .background(
                // Ticket background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Perforated edge effect
            PerforatedEdge()
                .frame(height: 20)
                .foregroundColor(Color(.systemBackground))
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    private func formatSeats(_ seats: [String]) -> String {
        if seats.count <= 3 {
            return seats.joined(separator: ", ")
        } else {
            return "\(seats.count) Seats"
        }
    }
}

// MARK: - Perforated Edge Effect
struct PerforatedEdge: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<25, id: \.self) { _ in
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Ticket Display Data Model
struct TicketDisplayData {
    let eventName: String
    let venueName: String
    let dateTime: String
    let seatNumbers: [String]
    let qrData: String
    let orderReference: String
    
    // Helper to create QR data string
    static func createQRData(orderId: String, eventName: String, date: String, seats: [String]) -> String {
        return "TICKET:\(orderId):\(eventName):\(date):\(seats.joined(separator: ","))"
    }
}

// MARK: - Preview
struct TicketCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                TicketCard(
                    ticketData: TicketDisplayData(
                        eventName: "Hamilton",
                        venueName: "Victoria Palace Theatre",
                        dateTime: "Sept 15, 2025 • 7:30 PM",
                        seatNumbers: ["A-12", "A-13"],
                        qrData: TicketDisplayData.createQRData(
                            orderId: "b55c7a7f-c552-4ce0",
                            eventName: "Hamilton",
                            date: "2025-09-15",
                            seats: ["A-12", "A-13"]
                        ),
                        orderReference: "B55C7A...C552"
                    )
                )
                
                TicketCard(
                    ticketData: TicketDisplayData(
                        eventName: "The Lion King",
                        venueName: "Lyceum Theatre",
                        dateTime: "Dec 25, 2025 • 2:30 PM",
                        seatNumbers: ["C-5", "C-6", "C-7", "C-8"],
                        qrData: TicketDisplayData.createQRData(
                            orderId: "a44b66c2-d441-3bd9",
                            eventName: "The Lion King",
                            date: "2025-12-25",
                            seats: ["C-5", "C-6", "C-7", "C-8"]
                        ),
                        orderReference: "A44B66...D441"
                    )
                )
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGray6))
    }
}
