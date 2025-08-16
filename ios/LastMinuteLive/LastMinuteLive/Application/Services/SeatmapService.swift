import Foundation

/// Application service for managing seatmap data and operations
/// Orchestrates domain logic and external data access
@MainActor
public final class SeatmapService: ObservableObject {
    
    // MARK: - Published State
    
    @Published public var model: SeatmapModel?
    @Published public var priceTiers: [PriceTier] = []
    @Published public var seatAvailability: [String: SeatAvailabilityStatus] = [:]
    @Published public var performanceId: String?
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var warnings: [String] = []
    
    // MARK: - Dependencies
    
    private let seatmapRepository: SeatmapRepositoryProtocol
    private let priceTierRepository: PriceTierRepositoryProtocol
    private let seatAvailabilityRepository: SeatAvailabilityRepositoryProtocol
    
    public init(
        seatmapRepository: SeatmapRepositoryProtocol,
        priceTierRepository: PriceTierRepositoryProtocol, 
        seatAvailabilityRepository: SeatAvailabilityRepositoryProtocol
    ) {
        self.seatmapRepository = seatmapRepository
        self.priceTierRepository = priceTierRepository
        self.seatAvailabilityRepository = seatAvailabilityRepository
    }
    
    // MARK: - Use Cases
    
    /// Load complete seatmap data for a show
    func loadSeatmapData(for show: Show) async {
        isLoading = true
        error = nil
        warnings.removeAll()
        
        do {
            print("[SeatmapService] 🎭 Loading seatmap data for show: \(show.id)")
            
            // Load seatmap structure
            let seatmapData = try await seatmapRepository.fetchSeatmap(for: show.id)
            self.model = seatmapData.model
            self.warnings = seatmapData.warnings
            
            // Load price tiers
            let tiers = try await priceTierRepository.fetchPriceTiers(for: show.id)
            self.priceTiers = tiers
            
            // Load seat availability
            let availabilityData = try await seatAvailabilityRepository.fetchSeatAvailability(for: show.id)
            self.seatAvailability = availabilityData.availability
            self.performanceId = availabilityData.performanceId
            
            print("[SeatmapService] ✅ Loaded: \(model?.seats.count ?? 0) seats, \(tiers.count) tiers, \(seatAvailability.count) availability entries")
            
        } catch {
            print("[SeatmapService] ❌ Error loading seatmap data: \(error)")
            self.error = "Failed to load seatmap: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Refresh seat availability only (for real-time updates)
    func refreshSeatAvailability(for show: Show) async {
        do {
            let availabilityData = try await seatAvailabilityRepository.fetchSeatAvailability(for: show.id)
            self.seatAvailability = availabilityData.availability
            print("[SeatmapService] 🔄 Refreshed seat availability: \(seatAvailability.count) entries")
        } catch {
            print("[SeatmapService] ❌ Error refreshing availability: \(error)")
        }
    }
    
    // MARK: - Business Logic Queries
    
    /// Get availability status for a specific seat
    public func getAvailabilityStatus(for seatId: String) -> SeatAvailabilityStatus {
        guard let status = seatAvailability[seatId] else {
            return .blocked // Safe default for unknown seats
        }
        return status
    }
    
    /// Get all available seats
    public func getAvailableSeats() -> [SeatNode] {
        guard let model = model else { return [] }
        
        return model.seats.filter { seat in
            getAvailabilityStatus(for: seat.id).canBeSelected()
        }
    }
    
    /// Get price tier for a seat
    public func getPriceTier(for seat: SeatNode) -> PriceTier? {
        guard let priceLevelId = seat.priceLevelId else { return nil }
        return priceTiers.first { $0.code == priceLevelId }
    }
    
    /// Get price per seat (first available tier as fallback)
    public func getDefaultPricePerSeat() -> Int {
        return priceTiers.first?.amountMinor ?? 2500 // £25 fallback
    }
    
    /// Validate seat selection according to business rules
    public func validateSeatSelection(
        seatId: String,
        currentSelection: Set<String>
    ) -> SeatSelectionResult {
        let availability = getAvailabilityStatus(for: seatId)
        return SeatSelectionRules.canSelectSeat(
            seatId: seatId,
            currentSelection: currentSelection,
            availability: availability
        )
    }
    
    /// Check if current selection can proceed to checkout
    public func canProceedToCheckout(selectedSeats: Set<String>) -> Bool {
        return SeatSelectionRules.canProceedToCheckout(selectedSeats: selectedSeats)
    }
    
    /// Calculate total price for selected seats
    public func calculateTotalPrice(for selectedSeats: Set<String>) -> Int {
        let pricePerSeat = getDefaultPricePerSeat()
        return selectedSeats.count * pricePerSeat
    }
    
    /// Get selected seat nodes from IDs
    public func getSelectedSeatNodes(from seatIds: Set<String>) -> [SeatNode] {
        guard let model = model else { return [] }
        return model.seats.filter { seatIds.contains($0.id) }
    }
}

// MARK: - Repository Protocols

/// Protocol for seatmap data access
public protocol SeatmapRepositoryProtocol {
    func fetchSeatmap(for showId: String) async throws -> (model: SeatmapModel, warnings: [String])
}

/// Protocol for price tier data access  
public protocol PriceTierRepositoryProtocol {
    func fetchPriceTiers(for showId: String) async throws -> [PriceTier]
}

/// Protocol for seat availability data access
public protocol SeatAvailabilityRepositoryProtocol {
    func fetchSeatAvailability(for showId: String) async throws -> (availability: [String: SeatAvailabilityStatus], performanceId: String?)
}