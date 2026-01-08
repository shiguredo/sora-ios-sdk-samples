import Foundation
import Sora
import WebRTC

/// Sora SDK関連の、アプリケーション全体で共通して行いたい処理を行うシングルトン・マネージャ・クラスです。
class RPCSoraSDKManager {
  /// RPCSoraSDKManagerのシングルトンインスタンスです。
  static let shared = RPCSoraSDKManager()

  private(set) var currentMediaChannel: MediaChannel?

  private init() {
    Logger.shared.level = .debug
    Sora.setWebRTCLogLevel(.info)
  }

  /// 新たにSoraに接続を試みます。接続に成功した場合、currentMediaChannelが更新されます。
  ///
  /// 既に接続されており、currentMediaChannelが設定されている場合は新たに接続ができないようにしてあります。
  /// その場合は、一旦先に `disconnect()` を呼び出して、現在の接続を終了してください。
  func connect(
    with configuration: Configuration,
    completionHandler: ((Error?) -> Void)?
  ) {
    guard currentMediaChannel == nil else {
      return
    }
    _ = Sora.shared.connect(configuration: configuration) { [weak self] mediaChannel, error in
      self?.currentMediaChannel = mediaChannel
      completionHandler?(error)
    }
  }

  /// 既に接続済みのmediaChannelから切断します。
  ///
  /// currentMediaChannelがnilで、まだ接続されていないときは、何もしないで終了します。
  func disconnect() {
    guard let mediaChannel = currentMediaChannel else {
      return
    }
    mediaChannel.disconnect(error: nil)
    currentMediaChannel = nil
  }
}
