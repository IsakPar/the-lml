import SwiftUI

/// Modal that appears when guest users tap "See My Tickets"
/// Gives them clear options instead of forcing authentication
struct TicketAccessModal: View {
    let customerEmail: String?
    let ticketData: CleanTicketData
    let onLoginAccount: () -> Void
    let onDownloadTickets: () -> Void
    let onDismiss: () -> Void
    
    @State private var showingEmailSent = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal content
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 40))
                        .foregroundColor(StageKit.brandEnd)
                    
                    Text("Access Your Tickets")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("To view your tickets in the app, you need to log in or create an account.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Primary action - Login/Create Account
                    Button(action: onLoginAccount) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Log In / Create Account")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(StageKit.brandGradient)
                        .cornerRadius(16)
                        .shadow(color: StageKit.brandEnd.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    
                    // Secondary action - No thanks
                    Button(action: onDownloadTickets) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.wave.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("No Thanks, I'm Good")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Reassurance section
                VStack(spacing: 12) {
                    // Divider
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                    
                    // Email confirmation
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                            
                            Text("Don't worry! Your tickets have already been emailed to:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        if let email = customerEmail, !email.isEmpty {
                            Text(email)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(StageKit.brandEnd)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.white.opacity(0.1))
                                )
                        }
                    }
                    
                    // Download and enjoy message
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(StageKit.brandStart)
                            
                            Text("Download Tickets Now")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(StageKit.brandStart)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "theatermasks")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Enjoy the show!")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                // Close button
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Email Sent Confirmation
struct EmailSentConfirmation: View {
    let email: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Check Your Email!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("We've sent your tickets to \(email)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            Button("Got It") {
                onDismiss()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 32)
            .background(StageKit.brandGradient)
            .cornerRadius(12)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThickMaterial)
        )
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview
struct TicketAccessModal_Previews: PreviewProvider {
    static var previews: some View {
        TicketAccessModal(
            customerEmail: "user@example.com",
            ticketData: CleanTicketData(
                from: PaymentSuccessData(
                    orderId: "test-order",
                    totalAmount: 5000,
                    currency: "GBP",
                    seatIds: ["seat1", "seat2"],
                    seatNodes: nil,
                    performanceName: "Hamilton",
                    performanceDate: "March 15, 2024 at 7:30 PM",
                    venueName: "Victoria Palace Theatre",
                    venueCoordinates: nil,
                    customerEmail: "user@example.com",
                    paymentMethod: "Card",
                    purchaseDate: "March 10, 2024"
                )
            ),
            onLoginAccount: {},
            onDownloadTickets: {},
            onDismiss: {}
        )
        .background(StageKit.bgGradient)
    }
}
