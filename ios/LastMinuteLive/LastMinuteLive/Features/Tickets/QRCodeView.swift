import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
  let token: String
  private let context = CIContext()
  private let filter = CIFilter.qrCodeGenerator()
  var body: some View {
    if let img = generateQR(from: token) {
      Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
    } else {
      Color.black
    }
  }
  private func generateQR(from string: String) -> UIImage? {
    filter.setValue(Data(string.utf8), forKey: "inputMessage")
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
      return UIImage(cgImage: cgimg)
    }
    return nil
  }
}


