import SwiftUI
// Import permissive seatmap types from sibling iOS module
// Files are included in the workspace; no module needed

struct SeatmapScreen: View {
  @EnvironmentObject var app: AppState
  let show: Show
  @Environment(\.dismiss) private var dismiss
  @State private var model: SeatmapModel? = nil
  @State private var warnings: [String] = []
  @State private var error: String? = nil
  @State private var loading = true
  @State private var tiers: [Tier] = []
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      StageKit.bgGradient.ignoresSafeArea()
      Group {
        if loading {
          ProgressView().tint(.white)
        } else if let e = error {
          VStack(spacing: 12) { Image(systemName: "exclamationmark.triangle"); Text(e) }
        } else if let m = model {
          ScrollView([.vertical, .horizontal]) {
            GeometryReader { geo in
              let scale = min(geo.size.width / max(m.viewportWidth, 1), 3.0)
              ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.white.opacity(0.04))
                  .frame(width: m.viewportWidth * scale, height: m.viewportHeight * scale)
                ForEach(m.seats, id: \.id) { seat in
                  let w = max(seat.w * scale, 8)
                  let h = max(seat.h * scale, 8)
                  RoundedRectangle(cornerRadius: 2)
                    .fill(fillColor(for: seat))
                    .frame(width: w, height: h)
                    .position(x: (seat.x + seat.w/2) * scale, y: (seat.y + seat.h/2) * scale)
                }
                if m.seats.isEmpty {
                  Text("No seats parsed\nCheck JSON keys: seats[x,y,row,section]")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.yellow)
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .position(x: 160, y: 80)
                }
                Text("STAGE")
                  .font(.caption.bold())
                  .padding(6)
                  .background(Color.black.opacity(0.5))
                  .cornerRadius(6)
                  .offset(x: 8, y: 8)
              }
              .frame(width: max(m.viewportWidth * scale + 32, geo.size.width), height: max(m.viewportHeight * scale + 32, geo.size.height), alignment: .topLeading)
              .padding(16)
            }
          }
          if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              ForEach(warnings, id: \.self) { Text($0).font(.caption2).foregroundColor(.yellow) }
            }
            .padding(10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .padding(.top, 56)
            .padding(.leading, 16)
          }
        }
      }
      .padding(.top, tiers.isEmpty ? 58 : 100)
      VStack(spacing: 0) {
        ZStack {
          HStack { // left for layout; back button
            Button(action: { dismiss() }) {
              Image(systemName: "chevron.backward")
                .foregroundColor(.white)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            }
            Spacer()
          }
          Text(show.title)
            .font(.headline)
            .lineLimit(1)
            .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
          LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)], startPoint: .top, endPoint: .bottom)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.15)), alignment: .bottom)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 8)
        )
        if !tiers.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(tiers, id: \.code) { t in
                HStack(spacing: 8) {
                  RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: t.color ?? "#999999").opacity(0.9))
                    .frame(width: 14, height: 10)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                  Text("\(t.name) \(formatGBP(t.amountMinor))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.92))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
              }
            }
            .padding(.horizontal, 16)
          }
          .background(
            Color.black.opacity(0.35)
              .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.12)), alignment: .bottom)
          )
        }
      }
    }
    .onAppear(perform: load)
  }
  private func load() {
    loading = true; error = nil
    Task { @MainActor in
      do {
        let (res, _) = try await app.api.request(path: "/v1/shows/" + show.id + "/seatmap", headers: ["X-Org-ID": Config.defaultOrgId])
        let seatmapId: String
        if let o = try JSONSerialization.jsonObject(with: res) as? [String: Any], let s = o["seatmapId"] as? String { seatmapId = s } else { throw NSError(domain: "seatmap", code: 404) }
        let (data, _) = try await app.api.request(path: "/v1/seatmaps/" + seatmapId, headers: ["X-Org-ID": Config.defaultOrgId])
        if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
          do {
            let raw = (obj["data"] as? [String: Any]) ?? obj
            let parsed0 = try SeatmapParser.parse(raw: raw)
            // Diagnostics
            print("[Seatmap] fetched seats=\(parsed0.seats.count)")
            // If viewport missing, derive view from densest cluster (robust fit)
            if parsed0.viewportWidth <= 1 || parsed0.viewportHeight <= 1 {
              let seats = parsed0.seats
              guard !seats.isEmpty else { throw NSError(domain: "seatmap", code: 422) }
              let xsRaw = seats.map { $0.x }
              let ysRaw = seats.map { $0.y }
              let minXR = xsRaw.min() ?? 0, maxXR = xsRaw.max() ?? 1
              let minYR = ysRaw.min() ?? 0, maxYR = ysRaw.max() ?? 1
              let gridN = 20
              let dx = max(1e-6, (maxXR - minXR) / Double(gridN))
              let dy = max(1e-6, (maxYR - minYR) / Double(gridN))
              var grid = Array(repeating: Array(repeating: 0, count: gridN), count: gridN)
              for s in seats {
                let ix = max(0, min(gridN-1, Int((s.x - minXR) / dx)))
                let iy = max(0, min(gridN-1, Int((s.y - minYR) / dy)))
                grid[iy][ix] += 1
              }
              var best = (ix: 0, iy: 0, count: -1)
              for iy in 0..<gridN { for ix in 0..<gridN { if grid[iy][ix] > best.count { best = (ix, iy, grid[iy][ix]) } } }
              let radius = 2
              var cMinX = max(0, best.ix - radius), cMaxX = min(gridN-1, best.ix + radius)
              var cMinY = max(0, best.iy - radius), cMaxY = min(gridN-1, best.iy + radius)
              let minX = minXR + Double(cMinX) * dx
              let maxX = minXR + Double(cMaxX + 1) * dx
              let minY = minYR + Double(cMinY) * dy
              let maxY = minYR + Double(cMaxY + 1) * dy
              var inCluster = 0
              for s in seats { if s.x >= minX && s.x <= maxX && s.y >= minY && s.y <= maxY { inCluster += 1 } }
              print("[Seatmap] cluster seats=\(inCluster) bounds x:[\(minX),\(maxX)] y:[\(minY),\(maxY)]")
              let pad: Double = 40
              let derived = SeatmapModel(
                id: parsed0.id,
                name: parsed0.name,
                version: parsed0.version,
                viewportWidth: max(240, (maxX - minX) + 2*pad),
                viewportHeight: max(240, (maxY - minY) + 2*pad),
                sections: parsed0.sections,
                seats: seats.map { s in
                  SeatNode(id: s.id, sectionId: s.sectionId, x: s.x - minX + pad, y: s.y - minY + pad, w: s.w, h: s.h, colorHex: s.colorHex, priceLevelId: s.priceLevelId, attrs: s.attrs)
                },
                priceLevels: parsed0.priceLevels,
                warnings: parsed0.warnings + ["viewport derived from densest cluster"]
              )
              self.model = derived
              self.warnings = derived.warnings
            } else {
              self.model = parsed0
              self.warnings = parsed0.warnings
            }
          } catch {
            self.error = "Failed to parse seatmap: \(error.localizedDescription)"
          }
        } else { self.error = "Invalid seatmap JSON" }
        // Fetch price tiers for legend
        let (ptData, _) = try await app.api.request(path: "/v1/shows/" + show.id + "/price-tiers", headers: ["X-Org-ID": Config.defaultOrgId])
        if let o = try JSONSerialization.jsonObject(with: ptData) as? [String: Any], let arr = o["data"] as? [[String: Any]] {
          self.tiers = arr.compactMap { d in
            let amt = (d["amount_minor"] as? NSNumber)?.intValue ?? d["amount_minor"] as? Int ?? 0
            guard let code = d["code"] as? String, let name = d["name"] as? String else { return nil }
            return Tier(code: code, name: name, amountMinor: amt, color: d["color"] as? String)
          }
        }
      } catch { self.error = error.localizedDescription }
      self.loading = false
    }
  }
}

// Coloring by tier or fallback seat color
private func fillColor(for seat: SeatNode) -> Color {
  if let hex = seat.colorHex { return Color(hex: hex).opacity(0.85) }
  return Color.green.opacity(0.75)
}

private struct Tier { let code: String; let name: String; let amountMinor: Int; let color: String? }
private func formatGBP(_ minor: Int) -> String { "£" + String(format: "%.0f", Double(minor)/100.0) }
private extension Color {
  init(hex: String) {
    let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    let r, g, b: Double
    if s.count == 6 {
      r = Double((v >> 16) & 0xff) / 255.0
      g = Double((v >> 8) & 0xff) / 255.0
      b = Double(v & 0xff) / 255.0
    } else {
      r = 0.6; g = 0.6; b = 0.6
    }
    self = Color(red: r, green: g, blue: b)
  }
}
