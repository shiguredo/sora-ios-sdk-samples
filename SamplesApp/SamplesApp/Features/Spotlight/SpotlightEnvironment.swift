import Foundation
import Sora

enum SpotlightEnvironment {
  // 接続するサーバーのシグナリング URL
  static var urls: [URL] { Environment.urls }

  // チャネル ID
  static var channelId: String { Environment.channelId }

  // type: connect に含めるメタデータ
  static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }

  static func makeConfiguration(
    channelId: String,
    videoCodec: VideoCodec,
    spotlightFocusRid: SpotlightRid,
    spotlightUnfocusRid: SpotlightRid,
    spotlightNumber: Int?,
    simulcast: Bool,
    dataChannelSignaling: Bool?,
    ignoreDisconnectWebSocket: Bool?,
    videoBitRate: Int?
  ) -> Configuration {
    var configuration = Configuration(urlCandidates: urls, channelId: channelId, role: .sendrecv)
    configuration.videoCodec = videoCodec
    configuration.spotlightFocusRid = spotlightFocusRid
    configuration.spotlightUnfocusRid = spotlightUnfocusRid
    configuration.spotlightNumber = spotlightNumber
    configuration.simulcastEnabled = simulcast
    configuration.dataChannelSignaling = dataChannelSignaling
    configuration.ignoreDisconnectWebSocket = ignoreDisconnectWebSocket
    configuration.cameraSettings.isEnabled = true
    configuration.signalingConnectMetadata = signalingConnectMetadata
    configuration.bundleId = UUID().uuidString
    configuration.spotlightEnabled = .enabled
    if let videoBitRate {
      configuration.videoBitRate = videoBitRate
    }
    return configuration
  }
}
