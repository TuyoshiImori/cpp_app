import Foundation
import Network

#if canImport(ifaddrs)
  import Darwin
#endif

/// Wi-Fi 経由でファイル 1 件を配信する最小限の HTTP サーバー
/// NWListener (Network.framework) を使用する
final class LocalHttpServer: ObservableObject {
  @Published var serverURL: String?
  @Published var isRunning: Bool = false

  private var listener: NWListener?
  private var fileData: Data?
  private var fileName: String = "export.zip"

  /// サーバーを起動してファイルを配信可能にする
  /// - Parameters:
  ///   - data: 配信するデータ
  ///   - fileName: ファイル名（Content-Disposition に使用）
  func start(data: Data, fileName: String) {
    self.fileData = data
    self.fileName = fileName

    let parameters = NWParameters.tcp
    parameters.allowLocalEndpointReuse = true

    do {
      listener = try NWListener(using: parameters)
    } catch {
      print("LocalHttpServer: リスナーの作成に失敗 \(error)")
      return
    }

    listener?.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready:
        guard let port = self.listener?.port?.rawValue else { return }
        let ip = self.localIPAddress() ?? "localhost"
        let url = "http://\(ip):\(port)/\(fileName)"
        DispatchQueue.main.async {
          self.serverURL = url
          self.isRunning = true
        }
      case .failed(let error):
        print("LocalHttpServer: エラー \(error)")
        DispatchQueue.main.async { self.isRunning = false }
      default:
        break
      }
    }

    listener?.newConnectionHandler = { [weak self] connection in
      self?.handleConnection(connection)
    }

    listener?.start(queue: .global(qos: .utility))
  }

  func stop() {
    listener?.cancel()
    listener = nil
    DispatchQueue.main.async {
      self.serverURL = nil
      self.isRunning = false
    }
  }

  // MARK: - Connection handling

  private func handleConnection(_ connection: NWConnection) {
    connection.start(queue: .global(qos: .utility))
    readRequest(connection)
  }

  private func readRequest(_ connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
      guard let self else { return }
      if error != nil || (data == nil && isComplete) {
        connection.cancel()
        return
      }
      // リクエストを受け取ったらすぐにファイルを返す
      self.sendFile(connection)
    }
  }

  private func sendFile(_ connection: NWConnection) {
    guard let data = fileData else {
      connection.cancel()
      return
    }

    let headers = [
      "HTTP/1.1 200 OK",
      "Content-Type: application/zip",
      "Content-Disposition: attachment; filename=\"\(fileName)\"",
      "Content-Length: \(data.count)",
      "Access-Control-Allow-Origin: *",
      "Connection: close",
      "",
      "",
    ].joined(separator: "\r\n")

    var response = headers.data(using: .utf8)!
    response.append(data)

    connection.send(content: response, completion: .contentProcessed({ _ in
      connection.cancel()
    }))
  }

  // MARK: - IP address

  private func localIPAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return nil }
    defer { freeifaddrs(ifaddr) }

    var ptr = ifaddr
    while let current = ptr {
      let interface = current.pointee
      // IPv4 のみ対象
      if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
        let name = String(cString: interface.ifa_name)
        // Wi-Fi (en0) を優先し、次点で en1, pdp_ip0 等
        if name == "en0" || (address == nil && name.hasPrefix("en")) {
          var addr = interface.ifa_addr.pointee
          var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          getnameinfo(
            &addr, socklen_t(interface.ifa_addr.pointee.sa_len),
            &hostname, socklen_t(hostname.count),
            nil, 0, NI_NUMERICHOST)
          let ip = String(cString: hostname)
          if name == "en0" {
            address = ip
          } else if address == nil {
            address = ip
          }
        }
      }
      ptr = current.pointee.ifa_next
    }
    return address
  }
}
