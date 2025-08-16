import Foundation
import CoreData
import Combine

// MARK: - Temporary Protocol for Testing

/// Temporary protocol until Core Data auto-generation is working
protocol TicketRepositoryProtocolTemp {
    func saveTemp(_ ticketModel: TicketDisplayModel) async throws
}

/// Temporary implementation for testing
final class TicketRepositoryTemp: TicketRepositoryProtocolTemp, ObservableObject {
    
    private let coreDataManager: CoreDataManager
    
    // Published array for SwiftUI integration
    @Published var tickets: [TicketDisplayModel] = []
    
    init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
        print("[TicketRepository] 📚 Temporary repository initialized")
    }
    
    func saveTemp(_ ticketModel: TicketDisplayModel) async throws {
        // Temporary implementation - just print for now
        print("[TicketRepository] ✅ Temp ticket saved: \(ticketModel.eventName)")
    }
}

/// Repository interface for ticket operations following DDD principles
protocol TicketRepositoryProtocol {
    func save(_ ticket: TicketDisplayModel) async throws
    func fetchAll(for userId: String) async throws -> [TicketDisplayModel]
    func fetchById(_ id: UUID) async throws -> TicketDisplayModel?
    func fetchByOrderId(_ orderId: String) async throws -> TicketDisplayModel?
    func delete(_ ticketId: UUID) async throws
    func markAsScanned(_ ticketId: UUID) async throws
    func updateSyncStatus(_ ticketId: UUID, status: TicketSyncStatus) async throws
    func fetchPendingSync() async throws -> [TicketDisplayModel]
}

// MARK: - Temporary Implementation
// TODO: Replace with Core Data implementation once auto-generation is working

/// Temporary in-memory implementation of TicketRepository  
final class TicketRepository: TicketRepositoryProtocol, ObservableObject {
    
    // Published array for SwiftUI integration
    @Published var tickets: [TicketDisplayModel] = []
    
    // In-memory storage for testing
    private var storedTickets: [String: TicketDisplayModel] = [:]
    private let queue = DispatchQueue(label: "ticket.repository", qos: .userInitiated)
    
    init(coreDataManager: CoreDataManager = .shared) {
        print("[TicketRepository] 📚 Temporary repository initialized (in-memory)")
    }
    
    // MARK: - Save Operations
    
    /// Save a new ticket to in-memory storage
    func save(_ ticketModel: TicketDisplayModel) async throws {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Check if ticket already exists
                if self.storedTickets[ticketModel.orderId] == nil {
                    self.storedTickets[ticketModel.orderId] = ticketModel
                    
                    DispatchQueue.main.async {
                        self.tickets = Array(self.storedTickets.values).sorted { $0.eventDate > $1.eventDate }
                        print("[TicketRepository] ✅ Ticket saved (in-memory): \(ticketModel.eventName)")
                    }
                } else {
                    print("[TicketRepository] ⚠️ Ticket already exists: \(ticketModel.orderId)")
                }
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Fetch all tickets for a specific user (in-memory)
    func fetchAll(for userId: String) async throws -> [TicketDisplayModel] {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                let userTickets = Array(self.storedTickets.values)
                    .sorted { ticket1, ticket2 in
                        // Sort by event date (upcoming first), then by purchase date (newest first)
                        if ticket1.eventDate != ticket2.eventDate {
                            return ticket1.eventDate > ticket2.eventDate
                        }
                        return ticket1.purchaseDate > ticket2.purchaseDate
                    }
                
                print("[TicketRepository] 📋 Fetched \(userTickets.count) tickets (in-memory)")
                continuation.resume(returning: userTickets)
            }
        }
    }
    
    /// Fetch a specific ticket by ID (in-memory)
    func fetchById(_ id: UUID) async throws -> TicketDisplayModel? {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let ticket = self.storedTickets.values.first { $0.id == id }
                continuation.resume(returning: ticket)
            }
        }
    }
    
    /// Fetch a ticket by order ID (in-memory)
    func fetchByOrderId(_ orderId: String) async throws -> TicketDisplayModel? {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let ticket = self.storedTickets[orderId]
                continuation.resume(returning: ticket)
            }
        }
    }
    
    /// Fetch tickets that need to be synced (in-memory)
    func fetchPendingSync() async throws -> [TicketDisplayModel] {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                let pendingTickets = Array(self.storedTickets.values)
                    .filter { $0.syncStatus != .synced }
                    .sorted { $0.purchaseDate < $1.purchaseDate }
                
                print("[TicketRepository] 🔄 Found \(pendingTickets.count) tickets pending sync (in-memory)")
                continuation.resume(returning: pendingTickets)
            }
        }
    }
    
    // MARK: - Update Operations
    
    /// Mark a ticket as scanned (in-memory)
    func markAsScanned(_ ticketId: UUID) async throws {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                for (orderId, ticket) in self.storedTickets {
                    if ticket.id == ticketId {
                        let updatedTicket = TicketDisplayModel(
                            id: ticket.id,
                            orderId: ticket.orderId,
                            eventName: ticket.eventName,
                            venueName: ticket.venueName,
                            eventDate: ticket.eventDate,
                            seatInfo: ticket.seatInfo,
                            qrData: ticket.qrData,
                            purchaseDate: ticket.purchaseDate,
                            totalAmount: ticket.totalAmount,
                            currency: ticket.currency,
                            customerEmail: ticket.customerEmail,
                            isScanned: true,
                            syncStatus: ticket.syncStatus
                        )
                        self.storedTickets[orderId] = updatedTicket
                        
                        DispatchQueue.main.async {
                            self.tickets = Array(self.storedTickets.values).sorted { $0.eventDate > $1.eventDate }
                            print("[TicketRepository] ✅ Ticket marked as scanned (in-memory): \(ticketId)")
                        }
                        break
                    }
                }
                continuation.resume()
            }
        }
    }
    
    /// Update sync status for a ticket (in-memory)
    func updateSyncStatus(_ ticketId: UUID, status: TicketSyncStatus) async throws {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                for (orderId, ticket) in self.storedTickets {
                    if ticket.id == ticketId {
                        let updatedTicket = TicketDisplayModel(
                            id: ticket.id,
                            orderId: ticket.orderId,
                            eventName: ticket.eventName,
                            venueName: ticket.venueName,
                            eventDate: ticket.eventDate,
                            seatInfo: ticket.seatInfo,
                            qrData: ticket.qrData,
                            purchaseDate: ticket.purchaseDate,
                            totalAmount: ticket.totalAmount,
                            currency: ticket.currency,
                            customerEmail: ticket.customerEmail,
                            isScanned: ticket.isScanned,
                            syncStatus: status
                        )
                        self.storedTickets[orderId] = updatedTicket
                        
                        DispatchQueue.main.async {
                            self.tickets = Array(self.storedTickets.values).sorted { $0.eventDate > $1.eventDate }
                            print("[TicketRepository] 🔄 Updated sync status (in-memory): \(status.rawValue)")
                        }
                        break
                    }
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a ticket from in-memory storage
    func delete(_ ticketId: UUID) async throws {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                for (orderId, ticket) in self.storedTickets {
                    if ticket.id == ticketId {
                        self.storedTickets.removeValue(forKey: orderId)
                        
                        DispatchQueue.main.async {
                            self.tickets = Array(self.storedTickets.values).sorted { $0.eventDate > $1.eventDate }
                            print("[TicketRepository] 🗑️ Ticket deleted (in-memory): \(ticketId)")
                        }
                        break
                    }
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - SwiftUI Integration
    
    /// Refresh published tickets for SwiftUI (in-memory)
    @MainActor
    func refreshPublishedTickets(for userId: String) async {
        do {
            let fetchedTickets = try await fetchAll(for: userId)
            self.tickets = fetchedTickets
            print("[TicketRepository] 🔄 Published tickets refreshed (in-memory): \(fetchedTickets.count)")
        } catch {
            print("[TicketRepository] ❌ Failed to refresh published tickets: \(error)")
            self.tickets = []
        }
    }
}

// MARK: - Repository Errors

enum TicketRepositoryError: LocalizedError {
    case ticketNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .ticketNotFound:
            return "Ticket not found"
        case .saveFailed(let error):
            return "Failed to save ticket: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch ticket: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete ticket: \(error.localizedDescription)"
        }
    }
}
