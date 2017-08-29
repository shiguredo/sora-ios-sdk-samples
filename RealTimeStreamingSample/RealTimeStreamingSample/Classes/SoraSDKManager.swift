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
     Sora SDKのConnectionです。
     殆どの場合、アプリケーション全体で一つだけConnectionを用意することになるので、シングルトンとして用意すると便利に使えます。
     */
    let connection: Connection
    
    /**
     シングルトンにしたいので、イニシャライザはprivateにしてあります。
     */
    private init() {
        
        // Sora SDKの接続先URLです。
        // お手元のSoraの接続先を指定してください。
        let url = URL(string: "wss://sora.example.com/signaling")!
        
        // Connectionを生成します。
        // チャンネルIDについては、接続時に設定画面から入力させるようにしたいので、一旦は空欄にしてあります。
        // またデバッグログを有効にしています。
        self.connection = Connection(URL: url, mediaChannelId: "")
        self.connection.eventLog.debugMode = true
    }
    
}
