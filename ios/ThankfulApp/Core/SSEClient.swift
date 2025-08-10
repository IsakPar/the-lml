import Foundation

final class SSEClient: NSObject, URLSessionDataDelegate {
  private var session: URLSession!
  private var task: URLSessionDataTask?
  private var buffer = Data()
  private var onEvent: ((String, String) -> Void)?
  private var onError: ((Error) -> Void)?

  override init() {
    super.init()
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 0
    config.timeoutIntervalForResource = 0
    session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }

  func start(url: URL, headers: [String: String] = [:], onEvent: @escaping (String, String) -> Void, onError: @escaping (Error) -> Void) {
    var req = URLRequest(url: url)
    headers.forEach { req.addValue($1, forHTTPHeaderField: $0) }
    req.addValue("text/event-stream", forHTTPHeaderField: "Accept")
    self.onEvent = onEvent
    self.onError = onError
    task = session.dataTask(with: req)
    task?.resume()
  }

  func stop() {
    task?.cancel()
    task = nil
    buffer.removeAll()
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    buffer.append(data)
    // Split by newlines and parse SSE fields
    while let range = buffer.firstRange(of: Data("\n\n".utf8)) ?? buffer.firstRange(of: Data("\r\n\r\n".utf8)) {
      let eventBlock = buffer.subdata(in: 0..<range.lowerBound)
      buffer.removeSubrange(0..<range.upperBound)
      if let text = String(data: eventBlock, encoding: .utf8) {
        parseEventBlock(text)
      }
    }
  }

  private func parseEventBlock(_ block: String) {
    var event = "message"
    var dataLines: [String] = []
    block.split(separator: "\n").forEach { line in
      if line.hasPrefix("event:") {
        event = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
      } else if line.hasPrefix("data:") {
        let d = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        dataLines.append(d)
      }
    }
    let data = dataLines.joined(separator: "\n")
    onEvent?(event, data)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let e = error { onError?(e) }
  }
}


