import Foundation

// MARK: - Domain Models

/// Represents a pricing tier with business rules
public struct PriceTier {
    let code: String
    let name: String
    let amountMinor: Int
    let color: String?
    
    /// Get display price in formatted currency
    func formattedPrice() -> String {
        return String(format: "£%.2f", Double(amountMinor) / 100)
    }
    
    /// Business rule: Is this a premium tier?
    func isPremium() -> Bool {
        return code.contains("premium")
    }
    
    /// Business rule: Is this tier restricted view?
    func isRestrictedView() -> Bool {
        return code.contains("restricted")
    }
}

/// Domain model for seat availability states
public enum SeatAvailabilityStatus {
    case available
    case held
    case sold
    case blocked
    
    init(from statusString: String) {
        switch statusString.lowercased() {
        case "available": self = .available
        case "held": self = .held
        case "sold": self = .sold
        case "blocked": self = .blocked
        default: self = .blocked // Safe default
        }
    }
    
    /// Business rule: Can this seat be selected?
    func canBeSelected() -> Bool {
        return self == .available
    }
}

/// Domain model for seat selection business rules
public struct SeatSelectionRules {
    
    /// Maximum seats that can be selected at once
    static let maxSeatsPerOrder = 8
    
    /// Minimum seats required for group booking
    static let minSeatsForGroup = 1
    
    /// Validates if seat can be added to current selection
    static func canSelectSeat(
        seatId: String,
        currentSelection: Set<String>,
        availability: SeatAvailabilityStatus
    ) -> SeatSelectionResult {
        
        // Rule 1: Check availability
        guard availability.canBeSelected() else {
            return .failure(.seatNotAvailable)
        }
        
        // Rule 2: Check if already selected
        if currentSelection.contains(seatId) {
            return .failure(.seatAlreadySelected)
        }
        
        // Rule 3: Check maximum limit
        if currentSelection.count >= maxSeatsPerOrder {
            return .failure(.maximumSeatsReached)
        }
        
        return .success
    }
    
    /// Validates if current selection can proceed to checkout
    static func canProceedToCheckout(selectedSeats: Set<String>) -> Bool {
        return selectedSeats.count >= minSeatsForGroup && 
               selectedSeats.count <= maxSeatsPerOrder
    }
}

/// Result of seat selection validation
public enum SeatSelectionResult {
    case success
    case failure(SeatSelectionError)
}

/// Errors that can occur during seat selection
public enum SeatSelectionError {
    case seatNotAvailable
    case seatAlreadySelected
    case maximumSeatsReached
    case minimumSeatsRequired
    
    var userMessage: String {
        switch self {
        case .seatNotAvailable:
            return "This seat is no longer available"
        case .seatAlreadySelected:
            return "Seat is already selected"
        case .maximumSeatsReached:
            return "Maximum \(SeatSelectionRules.maxSeatsPerOrder) seats allowed"
        case .minimumSeatsRequired:
            return "Please select at least \(SeatSelectionRules.minSeatsForGroup) seat"
        }
    }
}

/// Domain model for order creation data
public struct OrderCreationData {
    let performanceId: String
    let seatIds: [String]
    let totalAmountMinor: Int
    let customerEmail: String
    let currency: String
    
    init(
        performanceId: String, 
        seatIds: [String], 
        pricePerSeat: Int,
        customerEmail: String,
        currency: String = "GBP"
    ) {
        self.performanceId = performanceId
        self.seatIds = seatIds
        self.totalAmountMinor = seatIds.count * pricePerSeat
        self.customerEmail = customerEmail
        self.currency = currency
    }
    
    /// Business rule: Calculate total price
    func formattedTotal() -> String {
        return String(format: "£%.2f", Double(totalAmountMinor) / 100)
    }
}