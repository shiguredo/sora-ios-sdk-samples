import Foundation
import Sora
import WebRTC

private let logger = SamplesLogger.tagged("SoraSDKManager")

/// アプリ全体で単一の Sora 接続を管理します。
final class SoraSDKManager {
  static let shared = SoraSDKManager()

  /// 現在接続中の Sora SDK の MediaChannel です。
  private(set) var currentMediaChannel: MediaChannel?

  private init() {
    // SDK のログを表示します。
    // 送受信されるシグナリングの内容や接続エラーを確認できます。
    Logger.shared.level = .debug
    Sora.setWebRTCLogLevel(.info)
  }

  /// 新たに Sora に接続を試みます。接続に成功した場合、currentMediaChannel が更新されます。
  ///
  /// 既に接続されている場合は新たに接続を開始することはできません。
  /// 別の接続を行う場合は先に `disconnect()` を呼び出して、現在の接続を終了してください。
  ///
  /// - Parameters:
  ///   - configuration: 接続時設定です。各サンプルごとに必要なパラメータを指定します
  ///   - onReceiveSignaling: シグナリング受信時のコールバックです
  ///   - completionHandler: 接続結果のコールバックです
  func connect(
    configuration: Configuration,
    onReceiveSignaling: ((Signaling) -> Void)? = nil,
    completionHandler: ((Error?) -> Void)? = nil
  ) {
    // currentMediaChannel が存在する場合は既に接続済み
    guard currentMediaChannel == nil else {
      logger.warning(
        "[sample] SoraSDKManager.connect ignored: already connected. channelId: \(currentMediaChannel?.configuration.channelId ?? "-")"
      )
      return
    }

    configuration.mediaChannelHandlers.onReceiveSignaling = { signaling in
      onReceiveSignaling?(signaling)
    }

    _ = Sora.shared.connect(configuration: configuration) { [weak self] mediaChannel, error in
      self?.currentMediaChannel = mediaChannel
      completionHandler?(error)
    }
  }

  /// 接続済みの Sora の接続を終了します。
  /// 既に切断済みの場合は何もしません。
  func disconnect() {
    // currentMediaChannel が nil の場合は切断済み
    guard let mediaChannel = currentMediaChannel else {
      logger.warning("[sample] SoraSDKManager.disconnect ignored: not connected.")
      return
    }
    mediaChannel.disconnect(error: nil)
    currentMediaChannel = nil
  }
}
