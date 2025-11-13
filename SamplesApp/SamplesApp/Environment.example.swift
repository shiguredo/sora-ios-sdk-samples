import Foundation

/// 環境設定を記述します。
/// このファイルをコピーして、ファイル名を Environment.swift に変更してください。
enum Environment {
  // 接続するサーバーのシグナリング URL
  // 配列で複数の URL を指定することが可能です
  static let urls: [URL] = [URL(string: "wss://sora.example.com/signaling")!]

  // チャネル ID
  static let channelId = "sora"

  // type: connect に含めるメタデータ
  static let signalingConnectMetadata: Encodable? = nil

  // DataChannel メッセージングに使うラベル
  static let dataChannelLabels = ["#spam", "#egg"]
}
