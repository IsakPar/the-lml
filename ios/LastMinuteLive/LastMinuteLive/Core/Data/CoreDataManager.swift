import Foundation
import CoreData
import SwiftUI

/// Core Data stack manager for LastMinuteLive
/// Provides persistent storage for tickets with migration support
final class CoreDataManager: ObservableObject {
    
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LastMinuteLiveDataModel")
        
        // Configure for better performance and error handling
        let description = container.persistentStoreDescriptions.first
        description?.shouldInferMappingModelAutomatically = true
        description?.shouldMigrateStoreAutomatically = true
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production, you should handle this error appropriately
                print("[CoreData] ❌ Failed to load store: \(error), \(error.userInfo)")
                
                // For development, we can try to recover by deleting and recreating
                self.handleStoreLoadError(container: container, error: error)
            } else {
                print("[CoreData] ✅ Successfully loaded persistent store")
            }
        }
        
        // Enable automatic merging of changes from parent contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "ViewContext"
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    /// Main view context for UI operations (main thread only)
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// Background context for data operations
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    private init() {
        print("[CoreData] 🗄️ Initializing Core Data stack...")
    }
    
    // MARK: - Error Recovery
    
    private func handleStoreLoadError(container: NSPersistentContainer, error: NSError) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return
        }
        
        print("[CoreData] 🔧 Attempting to recover from store load error...")
        
        do {
            // Delete the corrupted store
            try FileManager.default.removeItem(at: storeURL)
            
            // Delete associated files
            let storeDirectory = storeURL.deletingLastPathComponent()
            let storeName = storeURL.deletingPathExtension().lastPathComponent
            
            let walFileURL = storeDirectory.appendingPathComponent("\(storeName).sqlite-wal")
            let shmFileURL = storeDirectory.appendingPathComponent("\(storeName).sqlite-shm")
            
            try? FileManager.default.removeItem(at: walFileURL)
            try? FileManager.default.removeItem(at: shmFileURL)
            
            // Retry loading
            container.loadPersistentStores { _, error in
                if let error = error {
                    print("[CoreData] ❌ Recovery failed: \(error)")
                } else {
                    print("[CoreData] ✅ Store recovered successfully")
                }
            }
            
        } catch {
            print("[CoreData] ❌ Failed to recover store: \(error)")
        }
    }
    
    // MARK: - Save Context
    
    /// Save the view context to persistent store
    func save() {
        let context = viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("[CoreData] ✅ Context saved successfully")
            } catch {
                print("[CoreData] ❌ Failed to save context: \(error)")
                
                // Log detailed error information
                if let nsError = error as NSError? {
                    print("[CoreData] Error details: \(nsError.localizedDescription)")
                    if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                        for detailedError in detailedErrors {
                            print("[CoreData] Detailed error: \(detailedError.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    /// Save context in background
    func saveInBackground() {
        let context = backgroundContext
        
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                    print("[CoreData] ✅ Background context saved successfully")
                } catch {
                    print("[CoreData] ❌ Failed to save background context: \(error)")
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Delete all tickets (for debugging/reset)
    func deleteAllTickets() {
        let context = backgroundContext
        
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Ticket")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
                
                DispatchQueue.main.async {
                    self.viewContext.reset()
                    print("[CoreData] 🧹 All tickets deleted")
                }
            } catch {
                print("[CoreData] ❌ Failed to delete all tickets: \(error)")
            }
        }
    }
    
    /// Get ticket count
    func getTicketCount() -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Ticket")
        
        do {
            return try viewContext.count(for: fetchRequest)
        } catch {
            print("[CoreData] ❌ Failed to count tickets: \(error)")
            return 0
        }
    }
    
    // MARK: - Memory Management
    
    /// Reset view context (clears all cached objects)
    func resetViewContext() {
        viewContext.reset()
        print("[CoreData] 🔄 View context reset")
    }
}


