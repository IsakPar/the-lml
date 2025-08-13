import SwiftUI

struct SeatmapLogView: View {
  let seats: [SeatNode]
  let canvas: CGSize
  let res: SeatmapTransformResult
  var body: some View {
    Color.clear.frame(width: 0, height: 0)
      .onAppear { log() }
  }
  private func log() {
    #if DEBUG
    // Sample seats from different positions to show variety
    let sampleIndices = [0, seats.count/4, seats.count/2, seats.count*3/4].filter { $0 < seats.count }
    let sample = sampleIndices.map { i in "(\(seats[i].x),\(seats[i].y))" }.joined(separator: ", ")
    
    // Also show Y-coordinate distribution
    let uniqueYs = Set(seats.map { $0.y }).sorted()
    let yRange = uniqueYs.isEmpty ? "none" : "[\(uniqueYs.first!)...\(uniqueYs.last!)] (\(uniqueYs.count) unique)"
    
    print("[Seatmap] seats=\(seats.count) canvas=\(Int(canvas.width))x\(Int(canvas.height)) bounds x:[\(res.minX),\(res.maxX)] y:[\(res.minY),\(res.maxY)] world=\(res.worldW)x\(res.worldH) scale=\(res.scale) dxdy=(\(res.dx),\(res.dy)) flippedY=\(res.flippedY) clamped=\(res.scaleClamped) warnings=\(res.warnings.joined(separator: ",")) yDistrib=\(yRange) samples=\(sample)")
    #endif
  }
}


