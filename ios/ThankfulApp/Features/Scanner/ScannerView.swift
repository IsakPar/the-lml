import SwiftUI
import AVFoundation

struct ScannerView: UIViewControllerRepresentable {
  typealias UIViewControllerType = ScannerVC
  let onCode: (String) -> Void
  func makeUIViewController(context: Context) -> ScannerVC { ScannerVC(onCode: onCode) }
  func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  private let session = AVCaptureSession()
  private let onCode: (String) -> Void
  init(onCode: @escaping (String) -> Void) { self.onCode = onCode; super.init(nibName: nil, bundle: nil) }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func viewDidLoad() {
    super.viewDidLoad()
    guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }
    if session.canAddInput(input) { session.addInput(input) }
    let output = AVCaptureMetadataOutput()
    if session.canAddOutput(output) { session.addOutput(output) }
    output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    output.metadataObjectTypes = [.qr]
    let preview = AVCaptureVideoPreviewLayer(session: session)
    preview.videoGravity = .resizeAspectFill
    preview.frame = view.layer.bounds
    view.layer.addSublayer(preview)
    session.startRunning()
  }
  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let str = obj.stringValue else { return }
    session.stopRunning()
    onCode(str)
  }
}


