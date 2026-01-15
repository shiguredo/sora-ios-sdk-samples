import Foundation
import Sora

enum SimulcastEnvironment {
  // 接続するサーバーのシグナリング URL
  static var urls: [URL] { Environment.urls }

  // チャネル ID
  static var channelId: String { Environment.channelId }

  // type: connect に含めるメタデータ
  static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }

  static func makeConfiguration(
    channelId: String,
    videoCodec: VideoCodec,
    simulcastRequestRid: SimulcastRequestRid,
    dataChannelSignaling: Bool?,
    ignoreDisconnectWebSocket: Bool?,
    videoBitRate: Int?
  ) -> Configuration {
    var configuration = Configuration(urlCandidates: urls, channelId: channelId, role: .sendrecv)
    configuration.videoCodec = videoCodec
    configuration.simulcastRequestRid = simulcastRequestRid
    configuration.dataChannelSignaling = dataChannelSignaling
    configuration.ignoreDisconnectWebSocket = ignoreDisconnectWebSocket
    configuration.cameraSettings.isEnabled = true
    configuration.signalingConnectMetadata = signalingConnectMetadata
    configuration.bundleId = UUID().uuidString
    configuration.simulcastEnabled = true
    if let videoBitRate {
      configuration.videoBitRate = videoBitRate
    }
    return configuration
  }
}
