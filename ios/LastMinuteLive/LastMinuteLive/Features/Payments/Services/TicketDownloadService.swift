import SwiftUI
import MessageUI

/// Service to handle ticket downloads and email functionality for guest users
@MainActor
class TicketDownloadService: ObservableObject {
    
    /// Download tickets for guest users
    static func downloadTicketsForGuest(ticketData: CleanTicketData) {
        print("[TicketDownload] 📥 Starting ticket download for guest user")
        print("[TicketDownload] 🎫 Order ID: \(ticketData.orderId)")
        print("[TicketDownload] 📧 Email: \(ticketData.customerEmail)")
        
        // Create downloadable ticket data
        let ticketContent = generateTicketContent(ticketData: ticketData)
        
        // Save to device or share
        shareTicketContent(content: ticketContent, eventName: ticketData.eventName)
    }
    
    /// Generate ticket content for download
    private static func generateTicketContent(ticketData: CleanTicketData) -> String {
        return """
        🎭 DIGITAL TICKET
        
        Event: \(ticketData.eventName)
        Date: \(ticketData.cleanDateTime)
        Venue: \(ticketData.venueName)
        
        Order ID: \(ticketData.orderId)
        Tickets: \(ticketData.seatCount)
        Total: \(ticketData.formattedTotal)
        
        📧 This ticket was sent to: \(ticketData.customerEmail)
        
        🎫 Present this confirmation at the venue.
        
        Thank you for your purchase!
        LastMinuteLive
        """
    }
    
    /// Share ticket content using system share sheet
    private static func shareTicketContent(content: String, eventName: String) {
        let activityController = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
        
        // Find the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("[TicketDownload] ❌ Could not find root view controller")
            return
        }
        
        // Present share sheet
        if let presentedViewController = rootViewController.presentedViewController {
            presentedViewController.present(activityController, animated: true)
        } else {
            rootViewController.present(activityController, animated: true)
        }
        
        print("[TicketDownload] ✅ Share sheet presented for \(eventName)")
    }
    
    /// Check if user can send emails
    static func canSendEmail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
    
    /// Open email app with ticket information
    static func openEmailApp(to email: String, subject: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try mailto first
        if let mailURL = URL(string: "mailto:\(encodedEmail)?subject=\(encodedSubject)") {
            if UIApplication.shared.canOpenURL(mailURL) {
                UIApplication.shared.open(mailURL)
                print("[TicketDownload] 📧 Opened email app with mailto")
                return
            }
        }
        
        // Fallback to Gmail
        if let gmailURL = URL(string: "googlegmail://co?to=\(encodedEmail)&subject=\(encodedSubject)") {
            if UIApplication.shared.canOpenURL(gmailURL) {
                UIApplication.shared.open(gmailURL)
                print("[TicketDownload] 📧 Opened Gmail app")
                return
            }
        }
        
        // Final fallback - just open mail app
        if let mailURL = URL(string: "message://") {
            if UIApplication.shared.canOpenURL(mailURL) {
                UIApplication.shared.open(mailURL)
                print("[TicketDownload] 📧 Opened default mail app")
                return
            }
        }
        
        print("[TicketDownload] ⚠️ Could not open any email app")
    }
}

// MARK: - Extension for CleanTicketData
extension CleanTicketData {
    var formattedTotal: String {
        let amount = Double(totalAmount) / 100.0
        return "£" + String(format: "%.2f", amount)
    }
}
