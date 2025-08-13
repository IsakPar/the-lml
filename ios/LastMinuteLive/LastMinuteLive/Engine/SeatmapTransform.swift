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
  var clampOutliers: Bool = true
  var paddingPx: CGFloat = 15.0 // Fixed padding in pixels around seatmap
  var useOptimalScaling: Bool = true // Use seat bounds + padding instead of viewport bounds
  var usePerfectCentering: Bool = true // Center actual seat midpoint, not bounding box
  var centeringOffsetX: CGFloat = 0.0 // Fine-tune horizontal centering (positive = shift right)
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

func computeSeatmapTransform(seats: [SeatNode], worldSize: CGSize? = nil, canvasSize: CGSize, options: SeatmapTransformOptions = SeatmapTransformOptions()) throws -> SeatmapTransformResult {
  guard !seats.isEmpty else { throw SeatmapTransformError.emptySeats }

  var warnings: [String] = []

  // Always calculate seat bounds for optimal scaling
  let xs = seats.map { CGFloat($0.x) }
  let ys = seats.map { CGFloat($0.y) }
  var seatMinX = xs.min() ?? 0
  var seatMaxX = xs.max() ?? 0
  var seatMinY = ys.min() ?? 0
  var seatMaxY = ys.max() ?? 0
  var seatWorldW = seatMaxX - seatMinX
  var seatWorldH = seatMaxY - seatMinY

  if seatWorldW == 0 || seatWorldH == 0 {
    warnings.append("degenerate-bounds")
    seatMinX -= options.epsilon/2; seatMaxX += options.epsilon/2
    seatMinY -= options.epsilon/2; seatMaxY += options.epsilon/2
    seatWorldW = seatMaxX - seatMinX; seatWorldH = seatMaxY - seatMinY
  }

  // Choose bounds for scaling: seat bounds (optimal) or viewport bounds (legacy)
  let (minX, maxX, minY, maxY, worldW, worldH): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
  
  if options.useOptimalScaling {
    // Use actual seat bounds for optimal screen filling
    (minX, maxX, minY, maxY, worldW, worldH) = (seatMinX, seatMaxX, seatMinY, seatMaxY, seatWorldW, seatWorldH)
    warnings.append("optimal-scaling-seat-bounds")
  } else if let world = worldSize, world.width > 0 && world.height > 0 {
    // Legacy: use API viewport dimensions
    (minX, maxX, minY, maxY, worldW, worldH) = (0, world.width, 0, world.height, world.width, world.height)
    warnings.append("legacy-api-viewport")
  } else {
    // Legacy fallback: use seat bounds
    (minX, maxX, minY, maxY, worldW, worldH) = (seatMinX, seatMaxX, seatMinY, seatMaxY, seatWorldW, seatWorldH)
    warnings.append("legacy-calculated-from-seats")
  }

  // Optional outlier clamp using P1-P99 if full span is highly skewed  
  // (Only apply when calculating bounds from seats, not when using API viewport)
  var finalMinX = minX, finalMaxX = maxX, finalMinY = minY, finalMaxY = maxY
  var finalWorldW = worldW, finalWorldH = worldH
  
  if options.clampOutliers && worldSize == nil {
    let xs = seats.map { CGFloat($0.x) }
    let ys = seats.map { CGFloat($0.y) }
    func quantile(_ arr: [CGFloat], _ p: CGFloat) -> CGFloat {
      if arr.isEmpty { return 0 }
      let sorted = arr.sorted()
      let idx = max(0, min(sorted.count - 1, Int((CGFloat(sorted.count - 1)) * p)))
      return sorted[idx]
    }
    let x1 = quantile(xs, 0.01)
    let x99 = quantile(xs, 0.99)
    let y1 = quantile(ys, 0.01)
    let y99 = quantile(ys, 0.99)
    let trW = max(options.epsilon, x99 - x1)
    let trH = max(options.epsilon, y99 - y1)
    let skewX = worldW / trW
    let skewY = worldH / trH
    if skewX > 3 || skewY > 3 {
      finalMinX = x1; finalMaxX = x99; finalMinY = y1; finalMaxY = y99
      finalWorldW = finalMaxX - finalMinX; finalWorldH = finalMaxY - finalMinY
      warnings.append("outlier-clamped")
    }
  }

  // Decide Y flip
  let flip: Bool = {
    if let override = options.flipOverride { return override }
    switch options.yAxis {
    case "up": return true
    case "down": return false
    default:
      // Heuristic: if more seats are below the midline (greater y), assume Cartesian-up and flip
      let ys = seats.map { CGFloat($0.y) }
      let midline = finalMinY + finalWorldH/2
      let below = ys.filter { $0 > midline }.count
      let above = ys.count - below
      return below > above
    }
  }()

  // Uniform scale with optimal padding handling
  let canvasW = max(canvasSize.width, 1)
  let canvasH = max(canvasSize.height, 1)
  
  let (effectiveCanvasW, effectiveCanvasH, paddingOffsetX, paddingOffsetY): (CGFloat, CGFloat, CGFloat, CGFloat)
  
  if options.useOptimalScaling {
    // Optimal scaling: reserve padding space, scale seat bounds to remaining space
    effectiveCanvasW = max(canvasW - 2 * options.paddingPx, 1)
    effectiveCanvasH = max(canvasH - 2 * options.paddingPx, 1)
    paddingOffsetX = options.paddingPx
    paddingOffsetY = options.paddingPx
    warnings.append("optimal-padding-applied")
  } else {
    // Legacy scaling: use full canvas
    effectiveCanvasW = canvasW
    effectiveCanvasH = canvasH
    paddingOffsetX = 0
    paddingOffsetY = 0
  }
  
  var scale = min(effectiveCanvasW / max(finalWorldW, 1), effectiveCanvasH / max(finalWorldH, 1))
  var clamped = false
  if scale < options.minScale { scale = options.minScale; clamped = true }
  if scale > options.maxScale { scale = options.maxScale; clamped = true }

  // Centering offsets after scale
  let dx: CGFloat
  let dy: CGFloat
  
  if options.usePerfectCentering && options.centerContent {
    // Perfect centering: center actual seat midpoint in available space
    let seatMidpointX = (seatMinX + seatMaxX) / 2
    let seatMidpointY = (seatMinY + seatMaxY) / 2
    let availableCenterX = effectiveCanvasW / 2
    let availableCenterY = effectiveCanvasH / 2
    
    // Calculate offset to put seat midpoint at screen center
    let perfectCenteringDx = availableCenterX - (seatMidpointX - finalMinX) * scale
    let perfectCenteringDy = availableCenterY - (seatMidpointY - finalMinY) * scale
    
    dx = paddingOffsetX + perfectCenteringDx + options.centeringOffsetX
    dy = paddingOffsetY + perfectCenteringDy
    warnings.append("perfect-centering-applied")
  } else {
    // Legacy centering: center bounding box
    let contentW = finalWorldW * scale
    let contentH = finalWorldH * scale
    let leftoverW = max(0, effectiveCanvasW - contentW)
    let leftoverH = max(0, effectiveCanvasH - contentH)
    let centeringDx = options.centerContent ? leftoverW / 2 : 0
    let centeringDy = options.centerContent ? leftoverH / 2 : 0
    dx = paddingOffsetX + centeringDx + options.centeringOffsetX
    dy = paddingOffsetY + centeringDy
  }

  // Radius scaling to keep visible across scales
  let r = max(options.minRadiusPx, min(options.baseRadiusPx / max(scale, 1e-9), options.maxRadiusPx))

  return SeatmapTransformResult(
    scale: scale,
    flippedY: flip,
    minX: finalMinX, maxX: finalMaxX, minY: finalMinY, maxY: finalMaxY,
    worldW: finalWorldW, worldH: finalWorldH,
    dx: dx, dy: dy,
    seatRadiusPx: r,
    scaleClamped: clamped,
    warnings: warnings
  )
}

#if DEBUG
@discardableResult
private func _logTransformDebug(seats: [SeatNode], canvas: CGSize, res: SeatmapTransformResult) -> Bool {
  let sample = seats.prefix(3).map { s in "(\(s.x),\(s.y))" }.joined(separator: ", ")
  print("[Seatmap] seats=\(seats.count) canvas=\(Int(canvas.width))x\(Int(canvas.height)) bounds x:[\(res.minX),\(res.maxX)] y:[\(res.minY),\(res.maxY)] world=\(res.worldW)x\(res.worldH) scale=\(res.scale) dxdy=(\(res.dx),\(res.dy)) flippedY=\(res.flippedY) clamped=\(res.scaleClamped) warnings=\(res.warnings.joined(separator: ",")) samples=\(sample)")
  return true
}
#endif


