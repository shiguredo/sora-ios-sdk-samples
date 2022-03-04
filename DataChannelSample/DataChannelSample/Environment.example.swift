import Foundation

/**
    環境設定を記述します。
    このファイルをコピーして、ファイル名を Environment.swift に変更してください。
 */
enum Environment {
    // Sora SDKの接続先URL。複数指定可能
    static let urlCandidates: [URL] = [URL(string: "wss://sora.example.com/signaling")!]

    // チャネル ID
    static let channelId = "sora"

    // type: connect に含めるメタデータ
    static let signalingConnectMetadata: Encodable? = nil

    // DataChannel メッセージングに使うラベル
    static let dataChannelLabels = ["#spam", "#egg"]
}
