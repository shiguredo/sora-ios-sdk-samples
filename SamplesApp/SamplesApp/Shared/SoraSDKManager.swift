import Foundation
import Sora
import WebRTC

/// アプリ全体で単一の Sora 接続を管理します。
final class SoraSDKManager {
  static let shared = SoraSDKManager()

  /// DataChannel サンプルでランダムバイナリを送るかどうか。
  var dataChannelRandomBinary: Bool = false

  /// 現在接続中の Sora SDK の MediaChannel です。
  private(set) var currentMediaChannel: MediaChannel?

  private init() {
    // SDK のログを表示します。
    // 送受信されるシグナリングの内容や接続エラーを確認できます。
    Logger.shared.level = .debug
    Sora.setWebRTCLogLevel(.info)
  }

  func connect(
    configuration: Configuration,
    completionHandler: ((Error?) -> Void)? = nil
  ) {
    guard currentMediaChannel == nil else {
      return
    }

    _ = Sora.shared.connect(configuration: configuration) { [weak self] mediaChannel, error in
      self?.currentMediaChannel = mediaChannel
      completionHandler?(error)
    }
  }

  func disconnect() {
    guard let mediaChannel = currentMediaChannel else {
      return
    }
    mediaChannel.disconnect(error: nil)
    currentMediaChannel = nil
  }
}
