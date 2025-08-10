package com.thankful.app.engine

data class SeatAttrs(val accessible: Boolean, val companion: Boolean, val obstructed: Boolean)
data class PriceLevel(val id: String, val name: String)
data class SeatNode(val id: String, val sectionId: String, val x: Double, val y: Double, val w: Double, val h: Double, val priceLevelId: String?, val attrs: SeatAttrs)
data class SectionNode(val id: String, val name: String)
data class SeatmapModel(val id: String, val name: String, val version: Int, val viewportWidth: Double, val viewportHeight: Double, val sections: List<SectionNode>, val seats: List<SeatNode>, val priceLevels: List<PriceLevel>, val warnings: List<String>)

object SeatmapParser {
  fun parse(raw: Map<String, Any?>): SeatmapModel {
    val id = (raw["_id"] as? String) ?: (raw["id"] as? String) ?: java.util.UUID.randomUUID().toString()
    val name = (raw["name"] as? String) ?: "Seatmap"
    val version = (raw["version"] as? Int) ?: 0
    val vw = (raw["viewportWidth"] as? Number)?.toDouble() ?: 1000.0
    val vh = (raw["viewportHeight"] as? Number)?.toDouble() ?: 1000.0
    val warnings = mutableListOf<String>()

    val priceLevels = mutableListOf<PriceLevel>()
    (raw["pricing"] as? List<Map<String, Any?>>)?.forEach {
      val pid = (it["price_level_id"] as? String) ?: (it["id"] as? String) ?: java.util.UUID.randomUUID().toString()
      val pname = (it["name"] as? String) ?: pid
      priceLevels.add(PriceLevel(pid, pname))
    }

    val sections = mutableListOf<SectionNode>()
    val seats = mutableListOf<SeatNode>()

    fun parseSeat(sectionId: String, dict: Map<String, Any?>) {
      val sid = (dict["id"] as? String) ?: java.util.UUID.randomUUID().toString()
      val x = (dict["x"] as? Number)?.toDouble() ?: 0.0
      val y = (dict["y"] as? Number)?.toDouble() ?: 0.0
      val w = (dict["w"] as? Number)?.toDouble() ?: (dict["width"] as? Number)?.toDouble() ?: 8.0
      val h = (dict["h"] as? Number)?.toDouble() ?: (dict["height"] as? Number)?.toDouble() ?: 8.0
      val attrs = SeatAttrs(
        accessible = (dict["is_accessible"] as? Boolean) == true,
        companion = (dict["is_companion_seat"] as? Boolean) == true,
        obstructed = (dict["is_obstructed_view"] as? Boolean) == true
      )
      val pl = dict["suggested_price_tier"] as? String
      seats.add(SeatNode(sid, sectionId, x, y, w, h, pl, attrs))
    }

    val secArr = raw["sections"] as? List<Map<String, Any?>>
    if (secArr != null) {
      secArr.forEach { s ->
        val sid = (s["id"] as? String) ?: java.util.UUID.randomUUID().toString()
        val sname = (s["name"] as? String) ?: sid
        sections.add(SectionNode(sid, sname))
        (s["seats"] as? List<Map<String, Any?>>)?.forEach { parseSeat(sid, it) }
      }
    } else {
      val seatArr = raw["seats"] as? List<Map<String, Any?>>
      if (seatArr != null) {
        val sid = "default"
        sections.add(SectionNode(sid, "Section"))
        seatArr.forEach { parseSeat(sid, it) }
        warnings.add("no sections provided; using default section")
      } else {
        throw IllegalArgumentException("no sections or seats arrays")
      }
    }

    return SeatmapModel(id, name, version, vw, vh, sections, seats, priceLevels, warnings)
  }
}


