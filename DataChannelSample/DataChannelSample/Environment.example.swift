import Foundation

/**
    環境設定を記述します。
    このファイルをコピーして、ファイル名を Environment.swift に変更してください。
 */
enum Environment {
    /**
     Sora SDKの接続先URLです。

     お手元のSoraの接続先を指定してください。
     */
    private static let targetURL = URL(string: "wss://sora.example.com/signaling")!
}
