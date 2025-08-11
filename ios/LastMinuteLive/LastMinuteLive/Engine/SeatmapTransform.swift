import CoreGraphics
import Foundation

struct SeatmapTransformOptions {
  var yAxis: String = "auto" // 'auto' | 'up' | 'down'
  var flipOverride: Bool? = nil // when set, overrides heuristic
  var minScale: CGFloat = 1e-4
  var maxScale: CGFloat = 1e4
  var epsilon: CGFloat = 1.0
  var centerContent: Bool = true
  var baseRadiusPx: CGFloat = 10.0
  var minRadiusPx: CGFloat = 6.0
  var maxRadiusPx: CGFloat = 18.0
}

struct SeatmapTransformResult {
  let scale: CGFloat
  let flippedY: Bool
  let minX: CGFloat
  let maxX: CGFloat
  let minY: CGFloat
  let maxY: CGFloat
  let worldW: CGFloat
  let worldH: CGFloat
  let dx: CGFloat // post-scale centering x offset
  let dy: CGFloat // post-scale centering y offset
  let seatRadiusPx: CGFloat
  let scaleClamped: Bool
  let warnings: [String]
}

enum SeatmapTransformError: Error { case emptySeats }

func computeSeatmapTransform(seats: [SeatNode], canvasSize: CGSize, options: SeatmapTransformOptions = SeatmapTransformOptions()) throws -> SeatmapTransformResult {
  guard !seats.isEmpty else { throw SeatmapTransformError.emptySeats }

  var warnings: [String] = []

  // Bounds
  let xs = seats.map { CGFloat($0.x) }
  let ys = seats.map { CGFloat($0.y) }
  var minX = xs.min() ?? 0
  var maxX = xs.max() ?? 0
  var minY = ys.min() ?? 0
  var maxY = ys.max() ?? 0
  var worldW = maxX - minX
  var worldH = maxY - minY

  if worldW == 0 || worldH == 0 {
    warnings.append("degenerate-bounds")
    minX -= options.epsilon/2; maxX += options.epsilon/2
    minY -= options.epsilon/2; maxY += options.epsilon/2
    worldW = maxX - minX; worldH = maxY - minY
  }

  // Decide Y flip
  let flip: Bool = {
    if let override = options.flipOverride { return override }
    switch options.yAxis {
    case "up": return true
    case "down": return false
    default:
      // Simple heuristic: if median y is in top 40% of world, assume data is 'up' and needs flip
      let sortedY = ys.sorted()
      let mid = sortedY.count/2
      let medianY = sortedY[mid]
      let rel = (medianY - minY) / max(worldH, 1)
      return rel < 0.4
    }
  }()

  // Uniform scale
  let canvasW = max(canvasSize.width, 1)
  let canvasH = max(canvasSize.height, 1)
  var scale = min(canvasW / max(worldW, 1), canvasH / max(worldH, 1))
  var clamped = false
  if scale < options.minScale { scale = options.minScale; clamped = true }
  if scale > options.maxScale { scale = options.maxScale; clamped = true }

  // Centering offsets after scale
  let leftoverW = max(0, canvasW - worldW * scale)
  let leftoverH = max(0, canvasH - worldH * scale)
  let dx = options.centerContent ? leftoverW / 2 : 0
  let dy = options.centerContent ? leftoverH / 2 : 0

  // Radius scaling to keep visible across scales
  let r = max(options.minRadiusPx, min(options.baseRadiusPx / max(scale, 1e-9), options.maxRadiusPx))

  return SeatmapTransformResult(
    scale: scale,
    flippedY: flip,
    minX: minX, maxX: maxX, minY: minY, maxY: maxY,
    worldW: worldW, worldH: worldH,
    dx: dx, dy: dy,
    seatRadiusPx: r,
    scaleClamped: clamped,
    warnings: warnings
  )
}


