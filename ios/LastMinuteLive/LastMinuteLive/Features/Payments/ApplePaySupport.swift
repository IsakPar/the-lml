import SwiftUI
import PassKit

struct ApplePayButtonView: UIViewRepresentable {
  let onTap: () -> Void
  func makeUIView(context: Context) -> PKPaymentButton {
    let btn = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
    btn.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
    return btn
  }
  func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
  func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }
  final class Coordinator: NSObject {
    let onTap: () -> Void
    init(onTap: @escaping () -> Void) { self.onTap = onTap }
    @objc func tap() { onTap() }
  }
}

final class ApplePayHandler: NSObject, PKPaymentAuthorizationControllerDelegate {
  private var completion: ((Bool) -> Void)?
  func start(amountMinor: Int, description: String, completion: @escaping (Bool) -> Void) {
    self.completion = completion
    let req = PKPaymentRequest()
    req.merchantIdentifier = Config.merchantIdentifier
    req.countryCode = Config.countryCode
    req.currencyCode = Config.currencyCode
    if #available(iOS 17.0, *) {
      req.merchantCapabilities = [.threeDSecure]
    } else {
      req.merchantCapabilities = [.capability3DS]
    }
    req.supportedNetworks = [.visa, .masterCard, .amex, .discover]
    let amount = NSDecimalNumber(value: Double(amountMinor) / 100.0)
    req.paymentSummaryItems = [PKPaymentSummaryItem(label: description, amount: amount)]
    let controller = PKPaymentAuthorizationController(paymentRequest: req)
    controller.delegate = self
    controller.present(completion: { _ in })
  }
  func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
    completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    self.completion?(true)
  }
  func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
    controller.dismiss(completion: nil)
  }
}


