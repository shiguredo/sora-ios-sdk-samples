import Foundation

enum DataChannelEnvironment {
    // 接続するサーバーのシグナリング URL
    static var urls: [URL] { Environment.urls }

    // チャネル ID
    static var channelId: String { Environment.channelId }

    // type: connect に含めるメタデータ
    static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }

    // DataChannel メッセージングに使うラベル
    static let dataChannelLabels = ["#spam", "#egg"]
}
