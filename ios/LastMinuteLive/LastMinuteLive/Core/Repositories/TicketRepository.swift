import Foundation
import CoreData
import Combine

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

/// Core Data implementation of TicketRepository
final class TicketRepository: TicketRepositoryProtocol, ObservableObject {
    
    private let coreDataManager: CoreDataManager
    
    // Published array for SwiftUI integration
    @Published var tickets: [TicketDisplayModel] = []
    
    init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
        print("[TicketRepository] 📚 Repository initialized")
    }
    
    // MARK: - Save Operations
    
    /// Save a new ticket to persistent storage
    func save(_ ticketModel: TicketDisplayModel) async throws {
        let context = coreDataManager.backgroundContext
        
        try await context.perform {
            // Check if ticket already exists
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "orderId == %@", ticketModel.orderId)
            
            let existingTickets = try context.fetch(fetchRequest)
            
            if existingTickets.isEmpty {
                // Create new ticket
                let _ = Ticket(
                    context: context,
                    orderId: ticketModel.orderId,
                    eventName: ticketModel.eventName,
                    venueName: ticketModel.venueName,
                    eventDate: ticketModel.eventDate,
                    seatInfo: ticketModel.seatInfo,
                    qrData: ticketModel.qrData,
                    purchaseDate: ticketModel.purchaseDate,
                    totalAmount: ticketModel.totalAmount,
                    currency: ticketModel.currency,
                    customerEmail: ticketModel.customerEmail,
                    userId: "" // Will be set by the service layer
                )
                
                try context.save()
                print("[TicketRepository] ✅ Ticket saved: \(ticketModel.eventName)")
            } else {
                print("[TicketRepository] ⚠️ Ticket already exists: \(ticketModel.orderId)")
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Fetch all tickets for a specific user
    func fetchAll(for userId: String) async throws -> [TicketDisplayModel] {
        let context = coreDataManager.viewContext
        
        return try await context.perform {
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Ticket.eventDate, ascending: true),
                NSSortDescriptor(keyPath: \Ticket.purchaseDate, ascending: false)
            ]
            
            let tickets = try context.fetch(fetchRequest)
            let displayModels = tickets.compactMap { ticket in
                guard ticket.isValid else { return nil }
                return TicketDisplayModel(from: ticket)
            }
            
            print("[TicketRepository] 📋 Fetched \(displayModels.count) tickets for user: \(userId)")
            return displayModels
        }
    }
    
    /// Fetch a specific ticket by ID
    func fetchById(_ id: UUID) async throws -> TicketDisplayModel? {
        let context = coreDataManager.viewContext
        
        return try await context.perform {
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let tickets = try context.fetch(fetchRequest)
            guard let ticket = tickets.first, ticket.isValid else { return nil }
            
            return TicketDisplayModel(from: ticket)
        }
    }
    
    /// Fetch a ticket by order ID
    func fetchByOrderId(_ orderId: String) async throws -> TicketDisplayModel? {
        let context = coreDataManager.viewContext
        
        return try await context.perform {
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "orderId == %@", orderId)
            fetchRequest.fetchLimit = 1
            
            let tickets = try context.fetch(fetchRequest)
            guard let ticket = tickets.first, ticket.isValid else { return nil }
            
            return TicketDisplayModel(from: ticket)
        }
    }
    
    /// Fetch tickets that need to be synced
    func fetchPendingSync() async throws -> [TicketDisplayModel] {
        let context = coreDataManager.viewContext
        
        return try await context.perform {
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "syncStatus != %@", TicketSyncStatus.synced.rawValue)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Ticket.updatedAt, ascending: true)
            ]
            
            let tickets = try context.fetch(fetchRequest)
            let displayModels = tickets.compactMap { ticket in
                guard ticket.isValid else { return nil }
                return TicketDisplayModel(from: ticket)
            }
            
            print("[TicketRepository] 🔄 Found \(displayModels.count) tickets pending sync")
            return displayModels
        }
    }
    
    // MARK: - Update Operations
    
    /// Mark a ticket as scanned
    func markAsScanned(_ ticketId: UUID) async throws {
        let context = coreDataManager.backgroundContext
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", ticketId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let tickets = try context.fetch(fetchRequest)
            guard let ticket = tickets.first else {
                throw TicketRepositoryError.ticketNotFound
            }
            
            ticket.markAsScanned()
            try context.save()
            
            print("[TicketRepository] ✅ Ticket marked as scanned: \(ticketId)")
        }
    }
    
    /// Update sync status for a ticket
    func updateSyncStatus(_ ticketId: UUID, status: TicketSyncStatus) async throws {
        let context = coreDataManager.backgroundContext
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", ticketId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let tickets = try context.fetch(fetchRequest)
            guard let ticket = tickets.first else {
                throw TicketRepositoryError.ticketNotFound
            }
            
            ticket.updateSyncStatus(status)
            try context.save()
            
            print("[TicketRepository] 🔄 Updated sync status: \(status.rawValue)")
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a ticket from persistent storage
    func delete(_ ticketId: UUID) async throws {
        let context = coreDataManager.backgroundContext
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<Ticket> = Ticket.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", ticketId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let tickets = try context.fetch(fetchRequest)
            guard let ticket = tickets.first else {
                throw TicketRepositoryError.ticketNotFound
            }
            
            context.delete(ticket)
            try context.save()
            
            print("[TicketRepository] 🗑️ Ticket deleted: \(ticketId)")
        }
    }
    
    // MARK: - SwiftUI Integration
    
    /// Refresh published tickets for SwiftUI
    @MainActor
    func refreshPublishedTickets(for userId: String) async {
        do {
            let fetchedTickets = try await fetchAll(for: userId)
            self.tickets = fetchedTickets
            print("[TicketRepository] 🔄 Published tickets refreshed: \(fetchedTickets.count)")
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
