import Foundation

// MARK: - SeatHoldService
@MainActor
class SeatHoldService: ObservableObject {
    @Published private(set) var heldSeats: Set<String> = []
    @Published private(set) var isHolding = false
    
    private let apiClient: ApiClient
    private var holdTokens: [String: String] = [:]  // seat_id -> hold_token
    private var holdExpirations: [String: Date] = [:]  // seat_id -> expiration
    
    init(apiClient: ApiClient) {
        self.apiClient = apiClient
        startExpirationTimer()
    }
    
    // MARK: - Public Methods
    
    /// Hold seats for the user (acquires Redis locks via /v1/holds API)
    func holdSeats(_ seatIds: [String], performanceId: String) async throws {
        guard !seatIds.isEmpty else { return }
        
        isHolding = true
        defer { isHolding = false }
        
        print("[SeatHold] Attempting to hold seats: \(seatIds)")
        
        // Prepare request body
        let requestBody = HoldRequest(
            performance_id: performanceId,
            seats: seatIds,
            ttl_seconds: 120  // 2 minute hold
        )
        
        // Generate idempotency key
        let idempotencyKey = "hold_\(UUID().uuidString)"
        
        // Call /v1/holds API
        do {
            let bodyData = try JSONEncoder().encode(requestBody)
            let (responseData, _) = try await apiClient.request(
                path: "/v1/holds",
                method: "POST",
                body: bodyData,
                headers: [
                    "Idempotency-Key": idempotencyKey
                ]
            )
            
            // ApiClient only returns successful responses (< 400), so this should be 201
            let response = try JSONDecoder().decode(HoldResponse.self, from: responseData)
            
            // Store hold tokens and expirations
            for seat in response.seats {
                holdTokens[seat.seat_id] = response.hold_token
                holdExpirations[seat.seat_id] = ISO8601DateFormatter().date(from: response.expires_at) ?? Date().addingTimeInterval(120)
            }
            
            // Update held seats
            heldSeats.formUnion(seatIds)
            print("[SeatHold] Successfully held \(seatIds.count) seats until \(response.expires_at)")
            
        } catch let apiError as ApiError {
            // Handle API errors (4xx/5xx responses)
            switch apiError {
            case .problem(let problem):
                if problem.status == 409 {
                    // Parse conflict response from the problem detail
                    print("[SeatHold] API Conflict: \(problem.title)")
                    throw SeatHoldError.conflict(conflictSeats: seatIds) // Fallback - could parse conflicts from problem if available
                } else {
                    throw SeatHoldError.holdFailed("API Error: \(problem.title)")
                }
            case .network(let message):
                throw SeatHoldError.networkError(message)
            }
        } catch let error as SeatHoldError {
            throw error  
        } catch {
            print("[SeatHold] Network error: \(error)")
            throw SeatHoldError.networkError(error.localizedDescription)
        }
    }
    
    /// Release held seats (remove from held set, let Redis TTL handle expiration)
    func releaseSeats(_ seatIds: [String]) {
        for seatId in seatIds {
            heldSeats.remove(seatId)
            holdTokens.removeValue(forKey: seatId)
            holdExpirations.removeValue(forKey: seatId)
        }
        print("[SeatHold] Released seats: \(seatIds)")
    }
    
    /// Check if a specific seat is currently held by this user
    func isSeatHeld(_ seatId: String) -> Bool {
        return heldSeats.contains(seatId)
    }
    
    /// Get hold token for a seat (needed for checkout)
    func holdToken(for seatId: String) -> String? {
        return holdTokens[seatId]
    }
    
    /// Get all held seats with their tokens (for checkout)
    func getAllHeldSeats() -> [(seatId: String, holdToken: String)] {
        return heldSeats.compactMap { seatId in
            guard let token = holdTokens[seatId] else { return nil }
            return (seatId: seatId, holdToken: token)
        }
    }
    
    // MARK: - Private Methods
    
    private func startExpirationTimer() {
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                self.cleanupExpiredHolds()
            }
        }
    }
    
    private func cleanupExpiredHolds() {
        let now = Date()
        let expiredSeats = holdExpirations.compactMap { (seatId, expiration) in
            expiration < now ? seatId : nil
        }
        
        if !expiredSeats.isEmpty {
            print("[SeatHold] Cleaning up expired holds: \(expiredSeats)")
            releaseSeats(expiredSeats)
        }
    }
}

// MARK: - Data Models

struct HoldRequest: Codable {
    let performance_id: String
    let seats: [String]
    let ttl_seconds: Int
}

struct HoldResponse: Codable {
    let hold_id: String
    let hold_token: String
    let expires_at: String
    let seats: [HoldSeat]
}

struct HoldSeat: Codable {
    let seat_id: String
    let status: String
}



// MARK: - Errors

enum SeatHoldError: LocalizedError {
    case conflict(conflictSeats: [String])
    case holdFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .conflict(let seats):
            return "Some seats are no longer available: \(seats.joined(separator: ", "))"
        case .holdFailed(let reason):
            return "Failed to hold seats: \(reason)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
