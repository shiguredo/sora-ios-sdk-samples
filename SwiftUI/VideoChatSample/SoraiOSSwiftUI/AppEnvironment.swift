import Foundation

enum AppEnvironment {
    // 接続するサーバーのシグナリング URL
    // 配列で複数の URL を指定することが可能です
    static let urls = [URL(string: "wss://0001.sora-zztkm.veltiosoft.dev/signaling")!]

    // チャネル ID
    static let channelId = "sora"

    // type: connect に含めるメタデータ
    static let signalingConnectMetadata: Encodable? = nil
}
