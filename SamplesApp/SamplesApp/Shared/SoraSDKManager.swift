import Foundation
import Sora
import WebRTC

private let logger = SamplesLogger.tagged("SoraSDKManager")

/// 購読 API が配送する接続失敗の snapshot を、`Error` を受け取るコールバックへ渡すためのエラーです。
///
/// `SoraEventError` は `Error` ではないため、`LocalizedError` へ写して渡します。
struct SoraConnectError: LocalizedError {
  /// エラーの説明
  let message: String

  /// エラーを作ります。
  ///
  /// - parameter message: エラーの説明
  init(message: String) {
    self.message = message
  }

  /// 購読 API が配送した接続失敗の snapshot からエラーを作ります。
  ///
  /// - parameter eventError: 接続失敗の snapshot。SDK の契約では `.connectFailed` は必ず
  ///   エラーを持つため、nil は payload が欠落した場合だけです
  init(_ eventError: SoraEventError?) {
    self.message = eventError?.message ?? "接続に失敗しました"
  }

  var errorDescription: String? { message }
}

/// `Sora.shared` を使う接続を管理します。
///
/// ScreenCast サンプルは接続結果の帰属を分けるために専用の `Sora` インスタンスを使うため、
/// このクラスでは管理しません。
final class SoraSDKManager {
  static let shared = SoraSDKManager()

  /// このマネージャーが使う Sora インスタンスです。
  private let sora = Sora.shared

  /// 現在接続中の Sora SDK の MediaChannel です。
  private(set) var currentMediaChannel: MediaChannel?

  /// 接続試行中のタスクです。nil でない間は接続を試行中です。
  ///
  /// 接続結果のイベントは接続を識別する情報として connectionId を持つだけで、どの試行の結果かは
  /// 分かりません。そのため試行を直列化して、別の接続の結果を取り違えないようにします。
  /// 中断する場合にも使います。
  private var connectionTask: ConnectionTask?

  private init() {
    // SDK のログを表示します。
    // 送受信されるシグナリングの内容や接続エラーを確認できます。
    Logger.shared.level = .debug
    Sora.setWebRTCLogLevel(.info)
  }

  /// 新たに Sora に接続を試みます。接続に成功した場合、currentMediaChannel が更新されます。
  ///
  /// 既に接続されている場合と接続を試行中の場合は、新たに接続を開始せずに
  /// completionHandler へエラーを返します。
  /// 別の接続を行う場合は先に `disconnect()` を呼び出して、現在の接続を終了してください。
  ///
  /// - Parameters:
  ///   - configuration: 接続時設定です。各サンプルごとに必要なパラメータを指定します
  ///   - completionHandler: 接続結果のコールバックです。MainActor 上で呼び出します
  func connect(
    configuration: Configuration,
    completionHandler: (@Sendable (Error?) -> Void)? = nil
  ) {
    // currentMediaChannel が存在する場合は既に接続済み
    guard currentMediaChannel == nil else {
      logger.warning(
        "[sample] SoraSDKManager.connect ignored: already connected. channelId: \(currentMediaChannel?.configuration.channelId ?? "-")"
      )
      notifyConnectFailure(SoraConnectError(message: "既に接続済みです"), to: completionHandler)
      return
    }
    // 接続を試行中の場合は、先の接続試行の結果を取り違えないように開始しない
    guard connectionTask == nil else {
      logger.warning("[sample] SoraSDKManager.connect ignored: already connecting.")
      notifyConnectFailure(SoraConnectError(message: "接続処理が進行中です"), to: completionHandler)
      return
    }

    // 接続の結果は購読 API の connected / connectFailed で受けるため、接続を開始する前に
    // 購読を開始する (購読を開始する前に配送されたイベントは届かない)。
    // 購読の解除は行いません (中止に伴う .connectFailed を受け取って試行中の状態を解放するため)。
    let events = sora.subscribeEvents()
    Task { [weak self] in
      for await event in events {
        guard let self else { return }
        switch event.kind {
        case .connected:
          // MediaChannel は Sendable ではないためイベントでは配送されない。
          // Sora が管理している接続の中から connectionId で解決する。
          // SDK の契約では connected は必ず接続 ID を持つ (欠落は防御的に接続失敗として扱う)。
          guard let connectionId = event.connectionId,
            let mediaChannel = sora.mediaChannels.first(where: {
              $0.connectionId == connectionId
            })
          else {
            logger.error(
              "[sample] SoraSDKManager.connect: media channel not found. connectionId: \(event.connectionId ?? "-")"
            )
            self.finishConnect(
              error: SoraConnectError(message: "接続した MediaChannel を取得できませんでした"),
              completionHandler: completionHandler
            )
            return
          }
          self.currentMediaChannel = mediaChannel
          self.finishConnect(error: nil, completionHandler: completionHandler)
          return
        case .connectFailed:
          self.finishConnect(
            error: SoraConnectError(event.error),
            completionHandler: completionHandler
          )
          return
        default:
          break
        }
      }
    }

    // 接続の結果は購読 API で受けるため、handler では何もしない。
    connectionTask = sora.connect(configuration: configuration) { @Sendable _, _ in }
  }

  /// 接続済みの Sora の接続を終了します。
  /// 既に切断済みの場合は何もしません。
  func disconnect() {
    // 接続試行中であれば試行を中止します。中止すると `.connectFailed` が配送されるため、
    // 購読は残したまま結果を待ちます (結果を受け取るまで次の接続を開始しないため、取り違えは
    // 起こりません)。試行中の状態は finishConnect で解放します。
    if let connectionTask {
      connectionTask.cancel()
      return
    }

    // currentMediaChannel が nil の場合は切断済み
    guard let mediaChannel = currentMediaChannel else {
      logger.warning("[sample] SoraSDKManager.disconnect ignored: not connected.")
      return
    }
    mediaChannel.disconnect(error: nil)
    currentMediaChannel = nil
  }

  /// 接続試行を終了し、結果を通知します。
  private func finishConnect(
    error: Error?,
    completionHandler: (@Sendable (Error?) -> Void)?
  ) {
    connectionTask = nil
    completionHandler?(error)
  }

  /// 接続を開始しなかった理由を通知します。
  ///
  /// `connect` の呼び出し元が接続処理中のままにならないように、呼び出しスタックの外で通知します。
  private func notifyConnectFailure(
    _ error: Error,
    to completionHandler: (@Sendable (Error?) -> Void)?
  ) {
    Task { @MainActor in
      completionHandler?(error)
    }
  }
}
