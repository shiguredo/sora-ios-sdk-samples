import Foundation
import Sora

/// Sora SDK関連の、アプリケーション全体で共通して行いたい処理を行うシングルトン・マネージャ・クラスです。
///
/// このようなクラスを用意しておくと、Sora SDKのConnectionをアプリケーション全体で一つだけ確実に管理する事が可能になるため、おすすめです。
class SoraSDKManager {
  /**
     SoraSDKManagerのシングルトンインスタンスです。
     */
  static let shared = SoraSDKManager()

  /**
     現在接続中のSora SDKのMediaChannelです。

     殆どの場合、アプリケーション全体で一つだけ同時にMediaChannelに接続することになるので、シングルトンとして用意すると便利に使えます。
     */
  private(set) var currentMediaChannel: MediaChannel?

  /**
     シングルトンにしたいので、イニシャライザはprivateにしてあります。
     */
  private init() {
    // SDK のログを表示します。
    // 送受信されるシグナリングの内容や接続エラーを確認できます。
    Logger.shared.level = .debug
    Sora.setWebRTCLogLevel(.info)
  }

  /**
     新たにSoraに接続を試みます。接続に成功した場合、currentMediaChannelが更新されます。

     既に接続されており、currentMediaChannelが設定されている場合は新たに接続ができないようにしてあります。
     その場合は、一旦先に `disconnect()` を呼び出して、現在の接続を終了してください。
     */
  func connect(
    channelId: String,
    role: Role,
    multistreamEnabled: Bool,
    videoCodec: VideoCodec = .default,
    completionHandler: ((Error?) -> Void)?
  ) {
    // 既にcurrentMediaChannelが設定されている場合は、接続済みとみなし、何もしないで終了します。
    guard currentMediaChannel == nil else {
      return
    }

    // Configurationを生成して、接続設定を行います。
    // 必須となる設定は URL、チャネル ID、ロール、マルチストリームの可否です。
    // その他の設定にはデフォルト値が指定されていますが、ここで必要に応じて自由に調整することが可能です。
    var configuration = Configuration(
      urlCandidates: Environment.urls,
      channelId: channelId,
      role: role,
      multistreamEnabled: multistreamEnabled)

    // 引数で指定された値を設定します。
    configuration.videoCodec = videoCodec
    configuration.cameraSettings.isEnabled = false
    configuration.signalingConnectMetadata = Environment.signalingConnectMetadata

    // Soraに接続を試みます。
    _ = Sora.shared.connect(configuration: configuration) { [weak self] mediaChannel, error in
      // 接続に成功した場合は、mediaChannelに値が返され、errorがnilになります。
      // 一方、接続に失敗した場合は、mediaChannelはnilとなり、errorが返されます。
      self?.currentMediaChannel = mediaChannel
      completionHandler?(error)
      NSLog(
        "[sample] mediaChannel.connectedUrl: \(String(describing: mediaChannel?.connectedUrl))"
      )
    }
  }

  /**
     既に接続済みのmediaChannelから切断します。

     currentMediaChannelがnilで、まだ接続されていないときは、何もしないで終了します。
     */
  func disconnect() {
    guard let mediaChannel = currentMediaChannel else {
      return
    }
    mediaChannel.disconnect(error: nil)
    currentMediaChannel = nil
  }
}
