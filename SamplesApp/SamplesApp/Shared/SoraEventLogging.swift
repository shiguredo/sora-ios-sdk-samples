import Foundation
import Sora

/// MediaChannel の `.disconnected` が運ぶ切断理由をログに出力します。
///
/// 購読 API の `case .disconnected:` から呼び出します。接続を複数持つ画面では `label` に
/// 接続を識別するラベルを渡します。
/// 購読している `Task` は呼び出し元の MainActor 隔離を継承するため、この関数も MainActor に置きます
/// (ログ出力も MainActor 隔離のため、nonisolated にはできません)。
///
/// - parameter event: 購読 API が配送したイベント
/// - parameter logger: 各画面のロガー
/// - parameter label: 接続を識別するラベル
@MainActor
func logMediaChannelDisconnected(
  _ event: SoraEvent,
  logger: SamplesLogger.TaggedLogger,
  label: String? = nil
) {
  let prefix =
    "[sample] mediaChannel.subscribeEvents.disconnected:" + (label.map { " \($0)" } ?? "")
  // MediaChannel の .disconnected は必ず closeEvent を持つ
  guard let closeEvent = event.closeEvent else {
    logger.error("\(prefix) closeEvent is missing")
    return
  }
  switch closeEvent {
  case .ok(let code, let reason):
    logger.info("\(prefix) code: \(code), reason: \(reason)")
  case .error(let error):
    logger.error("\(prefix) error: \(error.localizedDescription)")
  }
}
