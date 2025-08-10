import Foundation

public enum SeatmapParserError: Error { case invalidFormat(String) }

public struct SeatmapParser {
  // Permissive parser: supports varying coordinate representations.
  // Expected JSON keys: id/_id, name, version/hash, sections[], seats[] or sections[].seats[].
  public static func parse(raw: [String: Any]) throws -> SeatmapModel {
    let id = (raw["_id"] as? String) ?? (raw["id"] as? String) ?? UUID().uuidString
    let name = (raw["name"] as? String) ?? "Seatmap"
    let version = (raw["version"] as? Int) ?? 0
    var warnings: [String] = []

    // viewport (optional)
    let viewportWidth = (raw["viewportWidth"] as? Double) ?? 1000
    let viewportHeight = (raw["viewportHeight"] as? Double) ?? 1000

    // Collect sections and seats flexibly
    var sections: [SectionNode] = []
    var seats: [SeatNode] = []
    var priceLevels: [PriceLevel] = []

    // Price levels (optional)
    if let pricing = raw["pricing"] as? [[String: Any]] {
      for p in pricing {
        let pid = (p["price_level_id"] as? String) ?? (p["id"] as? String) ?? UUID().uuidString
        let pname = (p["name"] as? String) ?? pid
        priceLevels.append(.init(id: pid, name: pname))
      }
    }

    func parseSeat(sectionId: String, dict: [String: Any]) {
      let sid = (dict["id"] as? String) ?? UUID().uuidString
      // Coordinates may be provided as x,y,w,h or polygon/path we approximate to bbox
      let x = (dict["x"] as? Double) ?? 0
      let y = (dict["y"] as? Double) ?? 0
      let w = (dict["w"] as? Double) ?? (dict["width"] as? Double) ?? 8
      let h = (dict["h"] as? Double) ?? (dict["height"] as? Double) ?? 8
      var attrs: SeatAttributes = []
      if (dict["is_accessible"] as? Bool) == true { attrs.insert(.accessible) }
      if (dict["is_companion_seat"] as? Bool) == true { attrs.insert(.companion) }
      if (dict["is_obstructed_view"] as? Bool) == true { attrs.insert(.obstructed) }
      let pl = (dict["suggested_price_tier"] as? String)
      seats.append(.init(id: sid, sectionId: sectionId, x: x, y: y, w: w, h: h, priceLevelId: pl, attrs: attrs))
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
      let sid = "default"
      sections.append(.init(id: sid, name: "Section"))
      for seat in seatArr { parseSeat(sectionId: sid, dict: seat) }
      warnings.append("no sections provided; using default section")
    } else {
      throw SeatmapParserError.invalidFormat("no sections or seats arrays")
    }

    return SeatmapModel(id: id, name: name, version: version, viewportWidth: viewportWidth, viewportHeight: viewportHeight, sections: sections, seats: seats, priceLevels: priceLevels, warnings: warnings)
  }
}


