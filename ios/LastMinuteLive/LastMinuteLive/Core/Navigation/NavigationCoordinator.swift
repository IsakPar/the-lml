import SwiftUI
import Combine

/// Clean navigation coordinator following DDD principles
/// Manages app-level navigation state and provides centralized routing
@MainActor
final class NavigationCoordinator: ObservableObject {
    
    // MARK: - Published Navigation State
    @Published var selectedTab: AppTab = .shows
    @Published var showsPresentedSheet: ShowsSheet?
    @Published var ticketsPresentedSheet: TicketsSheet?
    
    // MARK: - Navigation Types
    enum AppTab: Int, CaseIterable {
        case shows = 0
        case tickets = 1
        case profile = 2
        
        var title: String {
            switch self {
            case .shows: return "Shows"
            case .tickets: return "My Tickets"
            case .profile: return "Profile"
            }
        }
        
        var iconName: String {
            switch self {
            case .shows: return "theatermasks"
            case .tickets: return "ticket"
            case .profile: return "person.circle"
            }
        }
    }
    
    enum ShowsSheet: Identifiable {
        case seatmap(Show)
        case login
        
        var id: String {
            switch self {
            case .seatmap(let show): return "seatmap_\(show.id)"
            case .login: return "login"
            }
        }
    }
    
    enum TicketsSheet: Identifiable {
        case qrScanner
        case ticketDetail(TicketData)
        
        var id: String {
            switch self {
            case .qrScanner: return "qr_scanner"
            case .ticketDetail(let ticket): return "ticket_\(ticket.id)"
            }
        }
    }
    
    // MARK: - Public Navigation Methods
    
    /// Navigate to shows tab and dismiss any presented sheets
    func navigateToShows() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = .shows
            dismissAllSheets()
        }
        print("[Navigation] 📱 Navigated to Shows tab")
    }
    
    /// Navigate to tickets tab and dismiss any presented sheets
    func navigateToTickets() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = .tickets
            dismissAllSheets()
        }
        print("[Navigation] 🎫 Navigated to Tickets tab")
    }
    
    /// Navigate to profile tab
    func navigateToProfile() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = .profile
            dismissAllSheets()
        }
        print("[Navigation] 👤 Navigated to Profile tab")
    }
    
    /// Present seatmap for a specific show
    func presentSeatmap(for show: Show) {
        showsPresentedSheet = .seatmap(show)
        print("[Navigation] 🎭 Presenting seatmap for: \(show.title)")
    }
    
    /// Present login sheet
    func presentLogin() {
        showsPresentedSheet = .login
        print("[Navigation] 🔐 Presenting login sheet")
    }
    
    /// Present QR scanner
    func presentQRScanner() {
        ticketsPresentedSheet = .qrScanner
        print("[Navigation] 📷 Presenting QR scanner")
    }
    
    /// Present ticket detail view
    func presentTicketDetail(_ ticket: TicketData) {
        ticketsPresentedSheet = .ticketDetail(ticket)
        print("[Navigation] 🎫 Presenting ticket detail for: \(ticket.eventName)")
    }
    
    /// Dismiss all presented sheets
    func dismissAllSheets() {
        showsPresentedSheet = nil
        ticketsPresentedSheet = nil
        print("[Navigation] ❌ Dismissed all sheets")
    }
    
    /// Dismiss shows sheets only
    func dismissShowsSheets() {
        showsPresentedSheet = nil
        print("[Navigation] ❌ Dismissed shows sheets")
    }
    
    /// Dismiss tickets sheets only
    func dismissTicketsSheets() {
        ticketsPresentedSheet = nil
        print("[Navigation] ❌ Dismissed tickets sheets")
    }
}

// MARK: - Navigation Data Models

/// Import existing Show struct from HomeView - no duplication needed

/// Ticket data model for navigation and display
struct TicketData: Identifiable, Codable {
    let id: String
    let orderId: String
    let eventName: String
    let venueName: String
    let seatInfo: String
    let eventDate: String
    let qrData: String
    let purchaseDate: String
    let isScanned: Bool
    
    var displayDate: String {
        // Format date for display
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: eventDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy • h:mm a"
            return displayFormatter.string(from: date)
        }
        return eventDate
    }
}
