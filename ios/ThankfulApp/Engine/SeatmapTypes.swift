import Foundation

public struct SeatAttributes: OptionSet, Codable {
  public let rawValue: Int
  public static let accessible = SeatAttributes(rawValue: 1 << 0)
  public static let companion  = SeatAttributes(rawValue: 1 << 1)
  public static let obstructed = SeatAttributes(rawValue: 1 << 2)
  public init(rawValue: Int) { self.rawValue = rawValue }
}

public struct PriceLevel: Codable, Hashable { public let id: String; public let name: String }

public struct SeatNode: Codable, Hashable {
  public let id: String
  public let sectionId: String
  public let x: Double
  public let y: Double
  public let w: Double
  public let h: Double
  public let priceLevelId: String?
  public let attrs: SeatAttributes
}

public struct SectionNode: Codable, Hashable { public let id: String; public let name: String }

public struct SeatmapModel: Codable {
  public let id: String
  public let name: String
  public let version: Int
  public let viewportWidth: Double
  public let viewportHeight: Double
  public let sections: [SectionNode]
  public let seats: [SeatNode]
  public let priceLevels: [PriceLevel]
  public let warnings: [String]
}


