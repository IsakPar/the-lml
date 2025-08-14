import SwiftUI
import CoreImage

struct SwipeableTickets: View {
    let cleanTicketData: CleanTicketData
    let seatNodes: [SeatNode]?
    @State private var currentIndex = 0
    
    private var individualTickets: [IndividualTicketData] {
        guard let nodes = seatNodes, !nodes.isEmpty else {
            // Fallback: create single ticket with all seats
            return [IndividualTicketData(
                seatDisplayName: cleanTicketData.readableSeats,
                qrData: cleanTicketData.qrData,
                eventName: cleanTicketData.eventName,
                venueName: cleanTicketData.venueName,
                dateTime: cleanTicketData.cleanDateTime,
                orderReference: cleanTicketData.orderReference
            )]
        }
        
        // Create individual tickets for each seat
        return nodes.map { seatNode in
            let seatDisplay = DataFormatters.getSeatDisplayText(from: seatNode) ?? seatNode.id
            let qrData = "TICKET:\(cleanTicketData.orderReference):SEAT:\(seatDisplay):\(cleanTicketData.eventName):\(cleanTicketData.cleanDateTime)"
            
            return IndividualTicketData(
                seatDisplayName: seatDisplay,
                qrData: qrData,
                eventName: cleanTicketData.eventName,
                venueName: cleanTicketData.venueName,
                dateTime: cleanTicketData.cleanDateTime,
                orderReference: cleanTicketData.orderReference
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if individualTickets.count > 1 {
                // Multiple tickets - show swipeable interface
                VStack(spacing: 12) {
                    // Ticket counter
                    HStack {
                        Text("Ticket \(currentIndex + 1) of \(individualTickets.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text("Swipe to view all tickets")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    
                    // Swipeable ticket cards
                    TabView(selection: $currentIndex) {
                        ForEach(Array(individualTickets.enumerated()), id: \.offset) { index, ticket in
                            IndividualTicketCard(ticketData: ticket)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 300)
                    
                    // Custom page indicator
                    PageIndicator(
                        numberOfPages: individualTickets.count,
                        currentIndex: currentIndex
                    )
                }
            } else {
                // Single ticket - show as before
                IndividualTicketCard(ticketData: individualTickets.first!)
            }
        }
    }
}

// MARK: - Individual Ticket Data
struct IndividualTicketData {
    let seatDisplayName: String    // "A12" or "C5"
    let qrData: String            // Individual QR for this specific seat
    let eventName: String
    let venueName: String
    let dateTime: String
    let orderReference: String
}

// MARK: - Individual Ticket Card
struct IndividualTicketCard: View {
    let ticketData: IndividualTicketData
    
    var body: some View {
        VStack(spacing: 0) {
            // Ticket content
            VStack(spacing: 20) {
                // Event header
                VStack(spacing: 8) {
                    Text(ticketData.eventName.uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .tracking(1.2)
                    
                    Text(ticketData.venueName)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                
                // Date and seat info row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATE & TIME")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.8)
                        
                        Text(ticketData.dateTime)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("SEAT")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.8)
                        
                        Text(ticketData.seatDisplayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)
                
                // QR Code for this specific seat
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                            .frame(width: 160, height: 160)
                        
                        if let qrImage = generateQRCode(from: ticketData.qrData) {
                            Image(uiImage: qrImage)
                                .resizable()
                                .frame(width: 140, height: 140)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("Seat \(ticketData.seatDisplayName)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("Present at venue entrance")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Order reference
                VStack(spacing: 6) {
                    Text("Order #\(ticketData.orderReference)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Powered by LastMinuteLive")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: StageKit.brandStart.opacity(0.3), location: 0),
                            .init(color: StageKit.brandEnd.opacity(0.2), location: 1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii) else { return nil }
        
        let context = CIContext()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scaleX: CGFloat = 140 / outputImage.extent.width
        let scaleY: CGFloat = 140 / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Custom Page Indicator
struct PageIndicator: View {
    let numberOfPages: Int
    let currentIndex: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? .white : .white.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
struct SwipeableTickets_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Single ticket example
                    Text("Single Ticket")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    SwipeableTickets(
                        cleanTicketData: CleanTicketData(
                            from: PaymentSuccessData(
                                orderId: "single-ticket-id",
                                totalAmount: 7500,
                                currency: "GBP",
                                seatIds: ["seat1"],
                                seatNodes: [
                                    SeatNode(id: "seat1", sectionId: "orchestra", x: 100, y: 200, w: 20, h: 20, colorHex: nil, priceLevelId: "premium", attrs: SeatAttributes(rawValue: 0), row: "A", number: "12")
                                ],
                                performanceName: "Hamilton",
                                performanceDate: "September 15, 2025 at 7:30 PM",
                                venueName: "Victoria Palace Theatre",
                                venueCoordinates: nil,
                                customerEmail: "user@example.com",
                                paymentMethod: "Card",
                                purchaseDate: "Sep 15, 2025 at 2:45 PM"
                            )
                        ),
                        seatNodes: [
                            SeatNode(id: "seat1", sectionId: "orchestra", x: 100, y: 200, w: 20, h: 20, colorHex: nil, priceLevelId: "premium", attrs: SeatAttributes(rawValue: 0), row: "A", number: "12")
                        ]
                    )
                    
                    // Multiple tickets example
                    Text("Multiple Tickets (Swipeable)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    SwipeableTickets(
                        cleanTicketData: CleanTicketData(
                            from: PaymentSuccessData(
                                orderId: "multi-ticket-id",
                                totalAmount: 15000,
                                currency: "GBP",
                                seatIds: ["seat1", "seat2", "seat3"],
                                seatNodes: [
                                    SeatNode(id: "seat1", sectionId: "royal_circle", x: 50, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "5"),
                                    SeatNode(id: "seat2", sectionId: "royal_circle", x: 68, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "6"),
                                    SeatNode(id: "seat3", sectionId: "royal_circle", x: 86, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "7")
                                ],
                                performanceName: "The Lion King",
                                performanceDate: "December 25, 2025 at 2:30 PM",
                                venueName: "Lyceum Theatre",
                                venueCoordinates: nil,
                                customerEmail: nil,
                                paymentMethod: "Apple Pay",
                                purchaseDate: "Dec 20, 2025 at 11:30 AM"
                            )
                        ),
                        seatNodes: [
                            SeatNode(id: "seat1", sectionId: "royal_circle", x: 50, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "5"),
                            SeatNode(id: "seat2", sectionId: "royal_circle", x: 68, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "6"),
                            SeatNode(id: "seat3", sectionId: "royal_circle", x: 86, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "7")
                        ]
                    )
                }
                .padding(.vertical, 40)
            }
        }
    }
}
