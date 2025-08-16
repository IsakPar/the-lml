import Foundation
import CoreData

// MARK: - Ticket Sync Status

enum TicketSyncStatus: String, CaseIterable {
    case pending = "pending"    // Not yet synced to backend
    case synced = "synced"      // Successfully synced
    case failed = "failed"     // Sync failed, needs retry
    case offline = "offline"   // Created offline, needs sync
    
    var displayText: String {
        switch self {
        case .pending: return "Pending Sync"
        case .synced: return "Synced"
        case .failed: return "Sync Failed"
        case .offline: return "Offline"
        }
    }
    
    var needsSync: Bool {
        return self != .synced
    }
}

// MARK: - Ticket Display Model

struct TicketDisplayModel: Identifiable {
    let id: UUID
    let orderId: String
    let eventName: String
    let venueName: String
    let eventDate: Date
    let seatInfo: String
    let qrData: String
    let purchaseDate: Date
    let totalAmount: Double
    let currency: String
    let customerEmail: String
    let isScanned: Bool
    let syncStatus: TicketSyncStatus
    
    // Computed display properties
    var displayEventDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: eventDate)
    }
    
    var displayPurchaseDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: purchaseDate)
    }
    
    var displayTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "\(currency) \(totalAmount)"
    }
    
    var shortEventDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        return formatter.string(from: eventDate)
    }
    
    // TODO: Re-enable once Core Data auto-generation is working
    /*
    init(from ticket: Ticket) {
        self.id = ticket.id ?? UUID()
        self.orderId = ticket.orderId ?? ""
        self.eventName = ticket.eventName ?? "Unknown Event"
        self.venueName = ticket.venueName ?? "Unknown Venue"
        self.eventDate = ticket.eventDate ?? Date()
        self.seatInfo = ticket.seatInfo ?? "Unknown Seat"
        self.qrData = ticket.qrData ?? ""
        self.purchaseDate = ticket.purchaseDate ?? Date()
        self.totalAmount = ticket.totalAmount
        self.currency = ticket.currency ?? "GBP"
        self.customerEmail = ticket.customerEmail ?? ""
        self.isScanned = ticket.isScanned
        self.syncStatus = TicketSyncStatus(rawValue: ticket.syncStatus ?? "pending") ?? .pending
    }
    */
    
    init(id: UUID, orderId: String, eventName: String, venueName: String, eventDate: Date, seatInfo: String, qrData: String, purchaseDate: Date, totalAmount: Double, currency: String, customerEmail: String, isScanned: Bool, syncStatus: TicketSyncStatus) {
        self.id = id
        self.orderId = orderId
        self.eventName = eventName
        self.venueName = venueName
        self.eventDate = eventDate
        self.seatInfo = seatInfo
        self.qrData = qrData
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.currency = currency
        self.customerEmail = customerEmail
        self.isScanned = isScanned
        self.syncStatus = syncStatus
    }
}
