import Foundation
import Sora

/**
 Sora SDK関連の、アプリケーション全体で共通して行いたい処理を行うシングルトン・マネージャ・クラスです。
 
 このようなクラスを用意しておくと、Sora SDKのConnectionをアプリケーション全体で一つだけ確実に管理する事が可能になるため、おすすめです。
 */
class SoraSDKManager {
    
    /**
     SoraSDKManagerのシングルトンインスタンスです。
     */
    static let shared: SoraSDKManager = SoraSDKManager()
    
    /**
     Sora SDKの接続先URLです。
     
     デフォルトの接続先は Sora Labo です。
     またはお手元のSoraの接続先を指定してください。
     */
    static let targetURL: URL = URL(string: "wss://sora-labo.shiguredo.jp/signaling")!
    
    /**
     Sora Labo 用のシグナリングキーです。
     
     Sora Labo のダッシュボードで発行されたシグナリングキーを指定してください。
     Sora Labo 以外のサーバに接続する場合は空のままで構いません。
     */
    static let signalingKey: String = ""

    /**
     接続先のチャネルIDです。
     
     Sora Labo を利用する場合は "<GitHub ユーザー名>@ <任意の Room ID>" のフォーマットで指定してください。
     */
    static let channelId: String = "__username__@sora-labo-sample"

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
        
        // スポットライトレガシー機能の設定です。
        // Sora Labo ではスポットライトレガシー機能は無効です。
        // お使いの Sora の設定を確認してください。
        // Sora.useSpotlightLegacy()
    }
    
    /**
     新たにSoraに接続を試みます。接続に成功した場合、currentMediaChannelが更新されます。
     
     既に接続されており、currentMediaChannelが設定されている場合は新たに接続ができないようにしてあります。
     その場合は、一旦先に `disconnect()` を呼び出して、現在の接続を終了してください。
     */
    func connect(channelId: String,
                 role: Role,
                 multistreamEnabled: Bool,
                 videoEnabled: Bool = true,
                 audioEnabled: Bool = true,
                 videoCodec: VideoCodec = .default,
                 videoCapturerOption: VideoCapturerDevice = .camera(settings: .default),
                 simulcastEnabled: Bool = false,
                 simulcastRid: SimulcastRid? = nil,
                 spotlightEnabled: Bool = false,
                 spotlightNumber: Int? = nil,
                 completionHandler: ((Error?) -> Void)?) {
        
        // 既にcurrentMediaChannelが設定されている場合は、接続済みとみなし、何もしないで終了します。
        guard currentMediaChannel == nil else {
            return
        }
        
        // Configurationを生成して、接続設定を行います。
        // 必須となる設定はurl, channelId, roleのみです。
        // その他の設定にはデフォルト値が指定されていますが、ここで必要に応じて自由に調整することが可能です。
        var configuration = Configuration(url: SoraSDKManager.targetURL, channelId: channelId, role: role,
                                          multistreamEnabled: multistreamEnabled)
        
        // 引数で指定された値を設定します。
        configuration.videoCodec = videoCodec
        configuration.videoCapturerDevice = videoCapturerOption
        configuration.simulcastEnabled = simulcastEnabled
        configuration.spotlightEnabled = spotlightEnabled ? .enabled : .disabled
        configuration.spotlightNumber = spotlightNumber

        configuration.signalingConnectMetadata = ["signaling_key": SoraSDKManager.signalingKey]
        
        // Soraに接続を試みます。
        let _ = Sora.shared.connect(configuration: configuration) { [weak self] mediaChannel, error in
            // 接続に成功した場合は、mediaChannelに値が返され、errorがnilになります。
            // 一方、接続に失敗した場合は、mediaChannelはnilとなり、errorが返されます。
            self?.currentMediaChannel = mediaChannel
            completionHandler?(error)
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
