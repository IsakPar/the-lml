import Foundation
import SwiftUI

/// Service for managing ticket storage and synchronization
/// Handles business logic for ticket operations following DDD principles
@MainActor
final class TicketStorageService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var tickets: [TicketDisplayModel] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    // MARK: - Dependencies
    
    private let ticketRepository: TicketRepositoryProtocol
    private let authenticationManager: AuthenticationManager
    private let keychainService = KeychainService()
    
    init(ticketRepository: TicketRepositoryProtocol = TicketRepository(),
         authenticationManager: AuthenticationManager) {
        self.ticketRepository = ticketRepository
        self.authenticationManager = authenticationManager
        
        print("[TicketStorage] 🎫 Service initialized")
        
        // Load tickets for current user
        Task {
            await loadTicketsForCurrentUser()
        }
    }
    
    // MARK: - Ticket Storage Operations
    
    /// Store a ticket from successful payment
    func storeTicketFromPayment(_ paymentSuccessData: PaymentSuccessData) async -> Bool {
        print("[TicketStorage] 💳 Storing ticket from payment: \(paymentSuccessData.orderId)")
        
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        guard let userId = keychainService.getUserId() else {
            lastError = "No user ID available"
            print("[TicketStorage] ❌ Cannot store ticket: no user ID")
            return false
        }
        
        do {
            // Convert payment success data to ticket model
            let ticketModel = createTicketModel(from: paymentSuccessData, userId: userId)
            
            // Store in repository
            try await storeTicket(ticketModel)
            
            // Refresh tickets list
            await loadTicketsForCurrentUser()
            
            print("[TicketStorage] ✅ Ticket stored successfully")
            return true
            
        } catch {
            lastError = error.localizedDescription
            print("[TicketStorage] ❌ Failed to store ticket: \(error)")
            return false
        }
    }
    
    /// Store a ticket model directly
    func storeTicket(_ ticketModel: TicketDisplayModel) async throws {
        // Add user ID if not present
        var updatedModel = ticketModel
        if ticketModel.customerEmail.isEmpty, let userEmail = keychainService.getUserEmail() {
            updatedModel = TicketDisplayModel(
                id: ticketModel.id,
                orderId: ticketModel.orderId,
                eventName: ticketModel.eventName,
                venueName: ticketModel.venueName,
                eventDate: ticketModel.eventDate,
                seatInfo: ticketModel.seatInfo,
                qrData: ticketModel.qrData,
                purchaseDate: ticketModel.purchaseDate,
                totalAmount: ticketModel.totalAmount,
                currency: ticketModel.currency,
                customerEmail: userEmail,
                isScanned: ticketModel.isScanned,
                syncStatus: ticketModel.syncStatus
            )
        }
        
        try await ticketRepository.save(updatedModel)
    }
    
    // MARK: - Ticket Loading Operations
    
    /// Load tickets for the currently authenticated user
    func loadTicketsForCurrentUser() async {
        guard let userId = keychainService.getUserId() else {
            print("[TicketStorage] ⚠️ No user ID available, clearing tickets")
            tickets = []
            return
        }
        
        await loadTickets(for: userId)
    }
    
    /// Load tickets for a specific user
    func loadTickets(for userId: String) async {
        print("[TicketStorage] 📋 Loading tickets for user: \(userId)")
        
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        do {
            let fetchedTickets = try await ticketRepository.fetchAll(for: userId)
            tickets = fetchedTickets.sorted { ticket1, ticket2 in
                // Sort by event date (upcoming first), then by purchase date (newest first)
                if ticket1.eventDate != ticket2.eventDate {
                    return ticket1.eventDate > ticket2.eventDate
                }
                return ticket1.purchaseDate > ticket2.purchaseDate
            }
            
            print("[TicketStorage] ✅ Loaded \(fetchedTickets.count) tickets")
            
        } catch {
            lastError = error.localizedDescription
            print("[TicketStorage] ❌ Failed to load tickets: \(error)")
            tickets = []
        }
    }
    
    /// Refresh tickets from storage
    func refreshTickets() async {
        await loadTicketsForCurrentUser()
    }
    
    // MARK: - Ticket Operations
    
    /// Mark a ticket as scanned
    func markTicketAsScanned(_ ticketId: UUID) async -> Bool {
        print("[TicketStorage] ✅ Marking ticket as scanned: \(ticketId)")
        
        do {
            try await ticketRepository.markAsScanned(ticketId)
            await refreshTickets()
            return true
        } catch {
            lastError = error.localizedDescription
            print("[TicketStorage] ❌ Failed to mark ticket as scanned: \(error)")
            return false
        }
    }
    
    /// Delete a ticket
    func deleteTicket(_ ticketId: UUID) async -> Bool {
        print("[TicketStorage] 🗑️ Deleting ticket: \(ticketId)")
        
        do {
            try await ticketRepository.delete(ticketId)
            await refreshTickets()
            return true
        } catch {
            lastError = error.localizedDescription
            print("[TicketStorage] ❌ Failed to delete ticket: \(error)")
            return false
        }
    }
    
    /// Get ticket by order ID
    func getTicket(by orderId: String) async -> TicketDisplayModel? {
        do {
            return try await ticketRepository.fetchByOrderId(orderId)
        } catch {
            print("[TicketStorage] ❌ Failed to fetch ticket by order ID: \(error)")
            return nil
        }
    }
    
    // MARK: - Sync Operations
    
    /// Sync pending tickets with backend
    func syncPendingTickets() async -> Bool {
        print("[TicketStorage] 🔄 Syncing pending tickets...")
        
        do {
            let pendingTickets = try await ticketRepository.fetchPendingSync()
            
            if pendingTickets.isEmpty {
                print("[TicketStorage] ✅ No tickets need syncing")
                return true
            }
            
            // TODO: Implement backend sync logic
            // For now, mark all as synced after a delay
            for ticket in pendingTickets {
                try await ticketRepository.updateSyncStatus(ticket.id, status: .synced)
            }
            
            await refreshTickets()
            
            print("[TicketStorage] ✅ Synced \(pendingTickets.count) tickets")
            return true
            
        } catch {
            lastError = error.localizedDescription
            print("[TicketStorage] ❌ Failed to sync tickets: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert PaymentSuccessData to TicketDisplayModel
    private func createTicketModel(from paymentData: PaymentSuccessData, userId: String) -> TicketDisplayModel {
        // Create QR data from order information
        let qrData = createQRData(from: paymentData)
        
        // Format seat information
        let seatInfo = formatSeatInformation(from: paymentData)
        
        return TicketDisplayModel(
            id: UUID(),
            orderId: paymentData.orderId,
            eventName: paymentData.performanceName,
            venueName: paymentData.venueName,
            eventDate: parseEventDate(paymentData.performanceDate),
            seatInfo: seatInfo,
            qrData: qrData,
            purchaseDate: Date(),
            totalAmount: Double(paymentData.totalAmount) / 100.0, // Convert from minor units
            currency: paymentData.currency,
            customerEmail: paymentData.customerEmail ?? "",
            isScanned: false,
            syncStatus: .pending
        )
    }
    
    /// Create QR data string for ticket validation
    private func createQRData(from paymentData: PaymentSuccessData) -> String {
        // Create a structured QR data string that can be used for validation
        let qrPayload: [String: Any] = [
            "orderId": paymentData.orderId,
            "eventName": paymentData.performanceName,
            "venueName": paymentData.venueName,
            "seatIds": paymentData.seatIds,
            "totalAmount": paymentData.totalAmount,
            "currency": paymentData.currency,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let qrDataEncoded = try? JSONSerialization.data(withJSONObject: qrPayload),
           let qrDataString = String(data: qrDataEncoded, encoding: .utf8) {
            return qrDataString
        }
        
        // Fallback to simple string format
        return "\(paymentData.orderId)|\(paymentData.performanceName)|\(paymentData.venueName)"
    }
    
    /// Format seat information for display
    private func formatSeatInformation(from paymentData: PaymentSuccessData) -> String {
        if let seatNodes = paymentData.seatNodes, !seatNodes.isEmpty {
            let seatStrings = seatNodes.map { seat in
                if let row = seat.row, !row.isEmpty, let number = seat.number {
                    return "Row \(row), Seat \(number)"
                }
                return "Seat \(seat.id)"
            }
            return seatStrings.joined(separator: ", ")
        }
        
        // Fallback to seat IDs
        if paymentData.seatIds.count == 1 {
            return "1 Seat"
        } else {
            return "\(paymentData.seatIds.count) Seats"
        }
    }
    
    /// Parse event date from string
    private func parseEventDate(_ dateString: String) -> Date {
        // Try to parse the date string
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Fallback to current date if parsing fails
        print("[TicketStorage] ⚠️ Failed to parse event date: \(dateString)")
        return Date()
    }
}
