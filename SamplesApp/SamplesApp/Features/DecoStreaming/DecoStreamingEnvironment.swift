import Foundation
import Sora

enum DecoStreamingEnvironment {
  // 接続するサーバーのシグナリング URL
  static var urls: [URL] { Environment.urls }

  // チャネル ID
  static var channelId: String { Environment.channelId }

  // type: connect に含めるメタデータ
  static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }

  static func makeConfiguration(
    channelId: String,
    role: Role,
    videoCodec: VideoCodec
  ) -> Configuration {
    var configuration = Configuration(urlCandidates: urls, channelId: channelId, role: role)
    configuration.videoCodec = videoCodec
    configuration.cameraSettings.isEnabled = false
    configuration.signalingConnectMetadata = signalingConnectMetadata
    return configuration
  }
}
