import Foundation

/// Infrastructure implementation for seatmap data access
final class SeatmapRepository: SeatmapRepositoryProtocol {
    
    private let apiClient: ApiClient
    private let orgId: String
    
    init(apiClient: ApiClient, orgId: String = Config.defaultOrgId) {
        self.apiClient = apiClient
        self.orgId = orgId
    }
    
    func fetchSeatmap(for showId: String) async throws -> (model: SeatmapModel, warnings: [String]) {
        print("[SeatmapRepository] 🎭 Fetching seatmap for show: \(showId)")
        
        // Step 1: Get seatmap ID for the show
        let seatmapIdPath = "/v1/shows/\(showId)/seatmap"
        let (seatmapIdResponse, _) = try await apiClient.request(
            path: seatmapIdPath, 
            headers: ["X-Org-ID": orgId]
        )
        
        guard let seatmapIdObj = try JSONSerialization.jsonObject(with: seatmapIdResponse) as? [String: Any],
              let seatmapId = seatmapIdObj["seatmapId"] as? String else {
            throw SeatmapRepositoryError.seatmapIdNotFound
        }
        
        print("[SeatmapRepository] 📍 Found seatmap ID: \(seatmapId)")
        
        // Step 2: Fetch actual seatmap data
        let seatmapPath = "/v1/seatmaps/\(seatmapId)"
        let (seatmapData, _) = try await apiClient.request(
            path: seatmapPath,
            headers: ["X-Org-ID": orgId]
        )
        
        guard let seatmapObj = try JSONSerialization.jsonObject(with: seatmapData) as? [String: Any] else {
            throw SeatmapRepositoryError.invalidSeatmapData
        }
        
        // Step 3: Parse seatmap using existing parser
        let rawSeatmapData = (seatmapObj["data"] as? [String: Any]) ?? seatmapObj
        
        do {
            let parsedSeatmap = try SeatmapParser.parse(raw: rawSeatmapData)
            print("[SeatmapRepository] ✅ Parsed \(parsedSeatmap.seats.count) seats")
            
            return (model: parsedSeatmap, warnings: parsedSeatmap.warnings)
            
        } catch {
            print("[SeatmapRepository] ❌ Failed to parse seatmap: \(error)")
            throw SeatmapRepositoryError.seatmapParsingFailed(error.localizedDescription)
        }
    }
}

/// Repository implementation for price tier data access
final class PriceTierRepository: PriceTierRepositoryProtocol {
    
    private let apiClient: ApiClient
    private let orgId: String
    
    init(apiClient: ApiClient, orgId: String = Config.defaultOrgId) {
        self.apiClient = apiClient
        self.orgId = orgId
    }
    
    func fetchPriceTiers(for showId: String) async throws -> [PriceTier] {
        print("[PriceTierRepository] 💰 Fetching price tiers for show: \(showId)")
        
        let path = "/v1/shows/\(showId)/price-tiers"
        let (responseData, _) = try await apiClient.request(
            path: path,
            headers: ["X-Org-ID": orgId]
        )
        
        guard let responseObj = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let tiersArray = responseObj["data"] as? [[String: Any]] else {
            throw PriceTierRepositoryError.invalidPriceTierData
        }
        
        let priceTiers = tiersArray.compactMap { tierDict -> PriceTier? in
            guard let code = tierDict["code"] as? String,
                  let name = tierDict["name"] as? String,
                  let amountMinor = tierDict["amount_minor"] as? Int else {
                return nil
            }
            
            return PriceTier(
                code: code,
                name: name,
                amountMinor: amountMinor,
                color: tierDict["color"] as? String
            )
        }
        
        print("[PriceTierRepository] ✅ Loaded \(priceTiers.count) price tiers")
        return priceTiers
    }
}

/// Repository implementation for seat availability data access
final class SeatAvailabilityRepository: SeatAvailabilityRepositoryProtocol {
    
    private let apiClient: ApiClient
    private let orgId: String
    
    init(apiClient: ApiClient, orgId: String = Config.defaultOrgId) {
        self.apiClient = apiClient
        self.orgId = orgId
    }
    
    func fetchSeatAvailability(for showId: String) async throws -> (availability: [String: SeatAvailabilityStatus], performanceId: String?) {
        print("[SeatAvailabilityRepository] 🎫 Fetching seat availability for show: \(showId)")
        
        let path = "/v1/shows/\(showId)/seat-availability"
        let (responseData, _) = try await apiClient.request(
            path: path,
            headers: ["X-Org-ID": orgId]
        )
        
        guard let responseObj = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw SeatAvailabilityRepositoryError.invalidAvailabilityData
        }
        
        // Parse availability map
        let availabilityMap: [String: SeatAvailabilityStatus]
        if let availabilityDict = responseObj["data"] as? [String: String] {
            availabilityMap = availabilityDict.mapValues { SeatAvailabilityStatus(from: $0) }
        } else {
            availabilityMap = [:]
        }
        
        // Extract performance ID
        let performanceId = responseObj["performance_id"] as? String
        
        print("[SeatAvailabilityRepository] ✅ Loaded availability for \(availabilityMap.count) seats")
        if let perfId = performanceId {
            print("[SeatAvailabilityRepository] 📅 Performance ID: \(perfId)")
        }
        
        return (availability: availabilityMap, performanceId: performanceId)
    }
}

// MARK: - Repository Errors

public enum SeatmapRepositoryError: Error {
    case seatmapIdNotFound
    case invalidSeatmapData  
    case seatmapParsingFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .seatmapIdNotFound:
            return "Seatmap ID not found for show"
        case .invalidSeatmapData:
            return "Invalid seatmap data received"
        case .seatmapParsingFailed(let details):
            return "Failed to parse seatmap: \(details)"
        }
    }
}

public enum PriceTierRepositoryError: Error {
    case invalidPriceTierData
    
    var localizedDescription: String {
        switch self {
        case .invalidPriceTierData:
            return "Invalid price tier data received"
        }
    }
}

public enum SeatAvailabilityRepositoryError: Error {
    case invalidAvailabilityData
    
    var localizedDescription: String {
        switch self {
        case .invalidAvailabilityData:
            return "Invalid seat availability data received"
        }
    }
}