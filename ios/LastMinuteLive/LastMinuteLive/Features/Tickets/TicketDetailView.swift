import SwiftUI
import PassKit
import MapKit

/// Detailed ticket view with QR code and actions
/// Provides full ticket information and native iOS integrations
struct TicketDetailView: View {
    let ticket: TicketDisplayModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                StageKit.bgGradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 16) {
                            // Status Badge
                            statusBadge
                            
                            // Event Information
                            VStack(spacing: 8) {
                                Text(ticket.eventName)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Label(ticket.venueName, systemImage: "location.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)
                        
                        // QR Code Section
                        qrCodeSection
                        
                        // Ticket Details
                        ticketDetailsSection
                        
                        // Action Buttons
                        actionButtonsSection
                        
                        // Bottom spacing
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            TicketShareSheet(ticket: ticket)
        }
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 8) {
            if ticket.isScanned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Scanned")
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            } else if ticket.eventDate < Date() {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Event Passed")
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "ticket.fill")
                    .foregroundColor(StageKit.brandStart)
                Text("Active")
                    .fontWeight(.medium)
                    .foregroundColor(StageKit.brandStart)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
    
    // MARK: - QR Code Section
    
    @ViewBuilder
    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            Text("Show this QR code for entry")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            
            // QR Code Container
            VStack(spacing: 16) {
                // 🔍 DEBUG: Log stored QR data
                let _ = {
                    print("[TicketDetailView] 📱 Displaying stored QR code:")
                    print("[TicketDetailView] - Order ID: \(ticket.orderId)")
                    print("[TicketDetailView] - Stored QR: \(ticket.qrData)")
                    print("[TicketDetailView] - QR Length: \(ticket.qrData.count) characters")
                }()
                
                TicketQRCodeView(
                    data: ticket.qrData,
                    size: 200,
                    backgroundColor: .white,
                    foregroundColor: .black
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                Text(ticket.orderId)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            .padding(20)
            .background(.regularMaterial)
            .cornerRadius(20)
        }
    }
    
    // MARK: - Ticket Details Section
    
    @ViewBuilder
    private var ticketDetailsSection: some View {
        VStack(spacing: 16) {
            Text("Ticket Details")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailCard(
                    icon: "calendar",
                    title: "Date & Time",
                    value: ticket.displayEventDate
                )
                
                DetailCard(
                    icon: "person.2.fill",
                    title: "Seat Information",
                    value: ticket.seatInfo
                )
                
                DetailCard(
                    icon: "creditcard.fill",
                    title: "Total Paid",
                    value: ticket.displayTotalAmount
                )
                
                DetailCard(
                    icon: "envelope.fill",
                    title: "Email",
                    value: ticket.customerEmail
                )
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Add to Wallet Button (if available)
            if PKPassLibrary.isPassLibraryAvailable() {
                PKAddPassButtonRepresentable(
                    style: .black,
                    onTap: {
                        handleAddToWallet()
                    }
                )
                .frame(height: 44)
                .cornerRadius(8)
            }
            
            // Directions Button
            Button(action: {
                openDirections()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text("Get Directions")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            
            // Share Button
            Button(action: {
                showingShareSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Ticket")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleAddToWallet() {
        print("[TicketDetail] 🏦 Add to Wallet tapped for ticket: \(ticket.orderId)")
        // TODO: Implement wallet integration
    }
    
    private func openDirections() {
        print("[TicketDetail] 🗺️ Directions tapped for venue: \(ticket.venueName)")
        
        // Create a basic coordinate for demonstration
        let coordinate = CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276) // London coordinates
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = ticket.venueName
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Detail Card Component

struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(StageKit.brandStart)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct TicketShareSheet: UIViewControllerRepresentable {
    let ticket: TicketDisplayModel
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let shareText = """
        🎭 \(ticket.eventName)
        📍 \(ticket.venueName)
        📅 \(ticket.shortEventDate)
        🎫 \(ticket.seatInfo)
        
        Order ID: \(ticket.orderId)
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PKAddPassButton Representable

struct PKAddPassButtonRepresentable: UIViewRepresentable {
    let style: PKAddPassButtonStyle
    let onTap: () -> Void
    
    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    class Coordinator: NSObject {
        let onTap: () -> Void
        
        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }
        
        @objc func buttonTapped() {
            onTap()
        }
    }
}

// MARK: - Preview

struct TicketDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TicketDetailView(
            ticket: TicketDisplayModel(
                id: UUID(),
                orderId: "ORDER-12345-ABCDEF",
                eventName: "Hamilton",
                venueName: "Theatre Royal Drury Lane",
                eventDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                seatInfo: "Row D, Seat 15",
                qrData: "sample-qr-data-for-hamilton-ticket",
                purchaseDate: Date(),
                totalAmount: 75.00,
                currency: "GBP",
                customerEmail: "user@example.com",
                isScanned: false,
                syncStatus: .synced
            )
        )
    }
}
