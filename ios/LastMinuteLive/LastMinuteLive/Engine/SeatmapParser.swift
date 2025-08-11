import Foundation

public enum SeatmapParserError: Error { case invalidFormat(String) }

public struct SeatmapParser {
  public static func parse(raw: [String: Any]) throws -> SeatmapModel {
    let id = (raw["_id"] as? String) ?? (raw["id"] as? String) ?? UUID().uuidString
    let name = (raw["name"] as? String) ?? "Seatmap"
    let version = (raw["version"] as? Int) ?? 0
    var warnings: [String] = []

    let viewportWidth = (raw["viewportWidth"] as? Double) ?? 1000
    let viewportHeight = (raw["viewportHeight"] as? Double) ?? 1000

    var sections: [SectionNode] = []
    var seats: [SeatNode] = []
    var priceLevels: [PriceLevel] = []

    if let pricing = raw["pricing"] as? [[String: Any]] {
      for p in pricing {
        let pid = (p["price_level_id"] as? String) ?? (p["id"] as? String) ?? UUID().uuidString
        let pname = (p["name"] as? String) ?? pid
        priceLevels.append(.init(id: pid, name: pname))
      }
    }

    func parseSeat(sectionId: String, dict: [String: Any]) {
      let sid = (dict["id"] as? String) ?? UUID().uuidString
      let x = (dict["x"] as? Double) ?? 0
      let y = (dict["y"] as? Double) ?? 0
      let w = (dict["w"] as? Double) ?? (dict["width"] as? Double) ?? 8
      let h = (dict["h"] as? Double) ?? (dict["height"] as? Double) ?? 8
      var attrs: SeatAttributes = []
      if (dict["is_accessible"] as? Bool) == true { attrs.insert(.accessible) }
      if (dict["is_companion_seat"] as? Bool) == true { attrs.insert(.companion) }
      if (dict["is_obstructed_view"] as? Bool) == true { attrs.insert(.obstructed) }
      let pl = (dict["suggested_price_tier"] as? String)
      let color = (dict["color"] as? String)
      seats.append(.init(id: sid, sectionId: sectionId, x: x, y: y, w: w, h: h, colorHex: color, priceLevelId: pl, attrs: attrs))
    }

    if let secArr = raw["sections"] as? [[String: Any]] {
      for s in secArr {
        let sid = (s["id"] as? String) ?? UUID().uuidString
        let sname = (s["name"] as? String) ?? sid
        sections.append(.init(id: sid, name: sname))
        if let seatArr = s["seats"] as? [[String: Any]] {
          for seat in seatArr { parseSeat(sectionId: sid, dict: seat) }
        }
      }
    } else if let seatArr = raw["seats"] as? [[String: Any]] {
      // Synthesize sections from seat.section when sections[] is missing
      var sectionIds: [String: String] = [:]
      for seat in seatArr {
        let sname = (seat["section"] as? String) ?? "Section"
        let norm = sname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sid = sectionIds[norm] ?? { let id = UUID().uuidString; sectionIds[norm] = id; return id }()
        if !sections.contains(where: { $0.id == sid }) { sections.append(.init(id: sid, name: sname)) }
        parseSeat(sectionId: sid, dict: seat)
      }
      warnings.append("sections synthesized from seat.section")
    } else {
      throw SeatmapParserError.invalidFormat("no sections or seats arrays")
    }

    return SeatmapModel(id: id, name: name, version: version, viewportWidth: viewportWidth, viewportHeight: viewportHeight, sections: sections, seats: seats, priceLevels: priceLevels, warnings: warnings)
  }
}


