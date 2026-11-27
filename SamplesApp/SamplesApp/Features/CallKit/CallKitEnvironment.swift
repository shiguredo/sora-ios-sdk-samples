import Foundation
import Sora

/// CallKit サンプルの接続設定を作ります。
///
/// CallKit は音声通話のためのサンプルなので、映像は送受信しません。
/// 着信は扱わず、発信のみを対象にしています。
enum CallKitEnvironment {
  // 接続するサーバーのシグナリング URL
  static var urls: [URL] { Environment.urls }

  // チャネル ID
  static var channelId: String { Environment.channelId }

  // type: connect に含めるメタデータ
  static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }

  /// 音声通話用の接続設定を作ります。
  ///
  /// CallKit が音声セッションを管理するため、SDK の音声ユニットは
  /// `Sora.usesManualAudio` で手動制御します。接続設定にはその制御に関する値を含めません。
  ///
  /// - parameter channelId: 接続するチャネル ID
  static func makeConfiguration(channelId: String) -> Configuration {
    var configuration = Configuration(urlCandidates: urls, channelId: channelId, role: .sendrecv)
    configuration.audioEnabled = true
    configuration.videoEnabled = false
    configuration.cameraSettings.isEnabled = false
    configuration.initialMicrophoneEnabled = true
    configuration.signalingConnectMetadata = signalingConnectMetadata
    return configuration
  }
}
