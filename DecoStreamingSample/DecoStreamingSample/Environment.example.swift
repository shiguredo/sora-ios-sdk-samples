import Foundation

enum Environment {

    // 接続するサーバーのシグナリング URL
    static let url = URL(string: "wss://sora.example.com/signaling")!

    // チャネル ID
    static let channelId = "sora"

}
