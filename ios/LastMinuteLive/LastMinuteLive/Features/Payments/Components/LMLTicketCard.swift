import SwiftUI
import CoreImage
import MapKit

struct LMLTicketCard: View {
    let ticketData: CleanTicketData
    
    var body: some View {
        VStack(spacing: 0) {
            // Main ticket content
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
                        
                        Text(ticketData.cleanDateTime)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("SEATS")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.8)
                        
                        Text(ticketData.readableSeats)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)
                
                // QR Code with glassmorphism frame
                VStack(spacing: 12) {
                    ZStack {
                        // QR Code background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                            .frame(width: 160, height: 160)
                        
                        // QR Code
                        if let qrImage = generateQRCode(from: ticketData.qrData) {
                            Image(uiImage: qrImage)
                                .resizable()
                                .frame(width: 140, height: 140)
                        } else {
                            // QR Code fallback
                            VStack(spacing: 8) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("Ticket Code")
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
            // LML Glassmorphism Card
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
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale the image up for crisp rendering
        let scaleX: CGFloat = 140 / outputImage.extent.width
        let scaleY: CGFloat = 140 / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Clean Ticket Data Model
struct CleanTicketData {
    let eventName: String
    let venueName: String
    let cleanDateTime: String // "Sept 15 • 19:30"
    let readableSeats: String  // "A12, A13" or "4 seats"
    let qrData: String
    let orderReference: String // "B55C7A...4E65"
    
    // Convert from PaymentSuccessData
    init(from successData: PaymentSuccessData, seatNodes: [SeatNode]? = nil) {
        self.eventName = successData.performanceName
        self.venueName = successData.venueName
        self.cleanDateTime = DataFormatters.formatPerformanceDateTime(successData.performanceDate)
        self.readableSeats = DataFormatters.formatSeatNumbers(
            seatIds: successData.seatIds,
            seatNodes: seatNodes
        )
        self.qrData = "TICKET:\(successData.orderId):\(successData.performanceName):\(cleanDateTime):\(successData.seatIds.joined(separator: ","))"
        self.orderReference = DataFormatters.formatOrderReference(successData.orderId)
    }
}

// MARK: - Preview
struct LMLTicketCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    LMLTicketCard(
                        ticketData: CleanTicketData(
                            from: PaymentSuccessData(
                                orderId: "b55c7a7f-c552-4ce0-aba0-e4f4a7414e65",
                                totalAmount: 7500,
                                currency: "GBP",
                                seatIds: ["8a523482-ddc9-4ee6-99c3", "396c72f1-e153-478c"],
                                seatNodes: [
                                    SeatNode(id: "8a523482-ddc9-4ee6-99c3", sectionId: "orchestra", x: 100, y: 200, w: 20, h: 20, colorHex: nil, priceLevelId: "premium", attrs: SeatAttributes(rawValue: 0), row: "A", number: "12"),
                                    SeatNode(id: "396c72f1-e153-478c", sectionId: "orchestra", x: 120, y: 200, w: 20, h: 20, colorHex: nil, priceLevelId: "premium", attrs: SeatAttributes(rawValue: 0), row: "A", number: "13")
                                ],
                                performanceName: "Hamilton",
                                performanceDate: "September 15, 2025 at 7:30 PM",
                                venueName: "Victoria Palace Theatre",
                                venueCoordinates: CLLocationCoordinate2D(latitude: 51.4942, longitude: -0.1358),
                                customerEmail: "user@example.com",
                                paymentMethod: "Card",
                                purchaseDate: "Sep 15, 2025 at 2:45 PM"
                            )
                        )
                    )
                    
                    LMLTicketCard(
                        ticketData: CleanTicketData(
                            from: PaymentSuccessData(
                                orderId: "a44b66c2-d441-3bd9-8fe2-c8e5a6d7b9f1",
                                totalAmount: 15000,
                                currency: "GBP",
                                seatIds: ["uuid1", "uuid2", "uuid3", "uuid4"],
                                seatNodes: [
                                    SeatNode(id: "uuid1", sectionId: "royal_circle", x: 50, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "5"),
                                    SeatNode(id: "uuid2", sectionId: "royal_circle", x: 68, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "6"),
                                    SeatNode(id: "uuid3", sectionId: "royal_circle", x: 86, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "7"),
                                    SeatNode(id: "uuid4", sectionId: "royal_circle", x: 104, y: 100, w: 18, h: 18, colorHex: nil, priceLevelId: "standard", attrs: SeatAttributes(rawValue: 0), row: "C", number: "8")
                                ],
                                performanceName: "The Lion King",
                                performanceDate: "December 25, 2025 at 2:30 PM",
                                venueName: "Lyceum Theatre",
                                venueCoordinates: CLLocationCoordinate2D(latitude: 51.5115, longitude: -0.1203),
                                customerEmail: nil,
                                paymentMethod: "Apple Pay",
                                purchaseDate: "Dec 20, 2025 at 11:30 AM"
                            )
                        )
                    )
                }
                .padding(.vertical, 40)
            }
        }
    }
}
