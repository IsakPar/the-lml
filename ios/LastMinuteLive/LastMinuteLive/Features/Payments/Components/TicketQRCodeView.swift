import SwiftUI
import CoreImage

struct TicketQRCodeView: View {
    let data: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        data: String, 
        size: CGFloat = 200, 
        backgroundColor: Color = .white,
        foregroundColor: Color = .black
    ) {
        self.data = data
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // QR Code Image
            if let qrImage = generateQRCode(from: data) {
                Image(uiImage: qrImage)
                    .resizable()
                    .frame(width: size, height: size)
                    .background(backgroundColor)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                // Fallback if QR generation fails
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("QR Code")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            
            // Scan instruction
            Text("Present this code at venue entrance")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: String.Encoding.ascii) else { return nil }
        
        let context = CIContext()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale the image up for crisp rendering
        let scaleX = size / outputImage.extent.width
        let scaleY = size / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Apply colors if not default black/white
        let coloredImage: CIImage
        if backgroundColor != .white || foregroundColor != .black {
            guard let colorFilter = CIFilter(name: "CIFalseColor") else { return nil }
            colorFilter.setValue(transformedImage, forKey: "inputImage")
            colorFilter.setValue(CIColor(backgroundColor), forKey: "inputColor0")  // Background
            colorFilter.setValue(CIColor(foregroundColor), forKey: "inputColor1") // Foreground
            coloredImage = colorFilter.outputImage ?? transformedImage
        } else {
            coloredImage = transformedImage
        }
        
        guard let cgImage = context.createCGImage(coloredImage, from: coloredImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Preview
struct TicketQRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TicketQRCodeView(
                data: "ORDER:b55c7a7f-c552-4ce0-aba0-e4f4a7414e65:HAMILTON:2025-09-15:A12,A13",
                size: 200
            )
            
            TicketQRCodeView(
                data: "TICKET_VERIFICATION_CODE",
                size: 120,
                backgroundColor: .blue.opacity(0.1),
                foregroundColor: .blue
            )
        }
        .padding()
    }
}

// MARK: - CIColor Extension
extension CIColor {
    convenience init(_ color: Color) {
        // Convert SwiftUI Color to UIColor to CIColor
        let uiColor = UIColor(color)
        self.init(color: uiColor)
    }
}
