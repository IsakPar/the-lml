import Foundation

public enum SeatmapParserError: Error { case invalidFormat(String) }

public struct SeatmapParser {
  public static func parse(raw: [String: Any]) throws -> SeatmapModel {
    let id = (raw["_id"] as? String) ?? (raw["id"] as? String) ?? UUID().uuidString
    let name = (raw["name"] as? String) ?? "Seatmap"
    let version = (raw["version"] as? Int) ?? 0
    var warnings: [String] = []

    // Read viewport from API response (nested in data field)
    let dataDict = raw["data"] as? [String: Any] ?? raw
    let viewport = dataDict["viewport"] as? [String: Any]
    let viewportWidth = (viewport?["width"] as? Double) ?? (raw["viewportWidth"] as? Double) ?? 1000
    let viewportHeight = (viewport?["height"] as? Double) ?? (raw["viewportHeight"] as? Double) ?? 1000

    var sections: [SectionNode] = []
    var seats: [SeatNode] = []
    var priceLevels: [PriceLevel] = []

    if let pricing = dataDict["pricing"] as? [[String: Any]] ?? raw["pricing"] as? [[String: Any]] {
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
      let pl = (dict["suggested_price_tier"] as? String) ?? (dict["priceLevelId"] as? String)
      let color = (dict["color"] as? String) ?? (dict["colorHex"] as? String)
      let row = dict["row"] as? String
      let number = dict["number"] as? String
      seats.append(.init(id: sid, sectionId: sectionId, x: x, y: y, w: w, h: h, colorHex: color, priceLevelId: pl, attrs: attrs, row: row, number: number))
    }

    if let secArr = dataDict["sections"] as? [[String: Any]] {
      for s in secArr {
        let sid = (s["id"] as? String) ?? UUID().uuidString
        let sname = (s["name"] as? String) ?? sid
        sections.append(.init(id: sid, name: sname))
        if let seatArr = s["seats"] as? [[String: Any]] {
          for seat in seatArr { parseSeat(sectionId: sid, dict: seat) }
        }
      }
    }
    
    // Always check for flat seats array regardless of sections presence
    if let seatArr = dataDict["seats"] as? [[String: Any]] {
      print("[Parser] Processing \(seatArr.count) seats from flat array")
      if sections.isEmpty {
        // Synthesize sections from seat.section when sections[] is missing
        var sectionIds: [String: String] = [:]
        for seat in seatArr {
          let sname = (seat["section"] as? String) ?? "Section"
          let norm = sname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          // Use the actual section name as the ID for easier legend mapping
          let sid = sectionIds[norm] ?? sname
          sectionIds[norm] = sid
          if !sections.contains(where: { $0.id == sid }) { sections.append(.init(id: sid, name: sname)) }
          parseSeat(sectionId: sid, dict: seat)
        }
        warnings.append("sections synthesized from seat.section")
      } else {
        // Map seats to existing sections by name
        for seat in seatArr {
          let sname = (seat["section"] as? String) ?? "Section"
          let norm = sname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          // Find existing section by name match
          let matchingSection = sections.first { section in
            section.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == norm
          }
          let sid = matchingSection?.id ?? sname // Use section name as fallback
          parseSeat(sectionId: sid, dict: seat)
        }
        warnings.append("seats mapped to existing sections")
        print("[Parser] Mapped \(seats.count) seats to \(sections.count) sections")
      }
    } else {
      throw SeatmapParserError.invalidFormat("no sections or seats arrays")
    }

    return SeatmapModel(id: id, name: name, version: version, viewportWidth: viewportWidth, viewportHeight: viewportHeight, sections: sections, seats: seats, priceLevels: priceLevels, warnings: warnings)
  }
}


