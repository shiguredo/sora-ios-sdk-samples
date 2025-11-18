import os

/// SamplesApp 全体で利用する os.Logger ラッパーです。
/// タグでモジュール名を指定してメッセージと一緒にロギングします。
///
/// ログを出力したい各モジュール先頭で
/// private let logger = SamplesLogger.tagged("<モジュール名>")
/// のように SamplesLogger インスタンスを生成します。
/// その後、logger.info("メッセージ") のようにログを出力します。
///
/// サンプルアプリの動作確認用のログのためプライバシー指定は全て public としています。
/// 個人情報等を含むログへの使用は想定していません。
struct SamplesLogger {
  struct TaggedLogger {
    fileprivate let tag: String

    func debug(_ message: String) {
      SamplesLogger.debug(tag: tag, message)
    }

    func info(_ message: String) {
      SamplesLogger.info(tag: tag, message)
    }

    func warning(_ message: String) {
      SamplesLogger.warning(tag: tag, message)
    }

    func error(_ message: String) {
      SamplesLogger.error(tag: tag, message)
    }
  }

  private static let logger = Logger(
    subsystem: "jp.shiguredo.sora-ios-sdk-samples",
    category: "SamplesApp"
  )

  static func tagged(_ tag: String) -> TaggedLogger {
    TaggedLogger(tag: tag)
  }

  static func debug(tag: String, _ message: String) {
    logger.debug("[\(tag, privacy: .public)] \(message, privacy: .public)")
  }

  static func info(tag: String, _ message: String) {
    logger.info("[\(tag, privacy: .public)] \(message, privacy: .public)")
  }

  static func warning(tag: String, _ message: String) {
    logger.warning("[\(tag, privacy: .public)] \(message, privacy: .public)")
  }

  static func error(tag: String, _ message: String) {
    logger.error("[\(tag, privacy: .public)] \(message, privacy: .public)")
  }
}
