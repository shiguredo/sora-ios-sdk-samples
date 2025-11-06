import Foundation

enum SimulcastEnvironment {
  // 接続するサーバーのシグナリング URL
  // 配列で複数の URL を指定することが可能です
  static let urls = [URL(string: "wss://sora.example.com/signaling")!]

  // チャネル ID
  static let channelId = "sora"

  // type: connect に含めるメタデータ
  static let signalingConnectMetadata: Encodable? = nil
}
