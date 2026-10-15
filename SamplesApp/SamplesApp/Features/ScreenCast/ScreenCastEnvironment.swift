import Foundation
import Sora

private let logger = SamplesLogger.tagged("ScreenCastConnection")

enum ScreenCastConnectionError: LocalizedError {
  case alreadyConnecting
  case alreadyConnected
  case missingMediaChannel(connection: String)

  var errorDescription: String? {
    switch self {
    case .alreadyConnecting:
      "接続処理が進行中です"
    case .alreadyConnected:
      "既に接続済みです"
    case .missingMediaChannel(let connection):
      "\(connection)の接続に失敗しました"
    }
  }
}

enum ScreenCastConnectionKind: String {
  case screen
  case camera
}

// ScreenCast サンプル用の接続マネージャーです
// 画面キャプチャとカメラの両方の接続を管理します
final class ScreenCastConnectionManager {
  static let shared = ScreenCastConnectionManager()

  // Sora.shared は SoraSDKManager と共有しているため、接続結果の帰属が混ざらないように
  // このサンプル専用のインスタンスを使います。
  // SDK のドキュメントにある「メディアチャネルのリストをグループに分ける」用途です。
  private let sora = Sora()

  private(set) var screenMediaChannel: MediaChannel?
  private(set) var cameraMediaChannel: MediaChannel?
  // 現在の接続セッションでカメラ接続を要求したかどうか
  private var isCameraConnectionRequested = false

  // 接続試行中のタスクです。nil でない間は接続を試行中です。
  private var connectionTask: ConnectionTask?

  private var isConnected: Bool {
    screenMediaChannel != nil || cameraMediaChannel != nil
  }

  var isActive: Bool {
    isConnected || connectionTask != nil
  }

  private init() {}

  func connect(
    channelId: String,
    videoCodec: VideoCodec,
    isCameraEnabled: Bool = true,
    completionHandler: (@Sendable (Error?) -> Void)? = nil
  ) {
    // 接続試行中かチェックします
    guard connectionTask == nil else {
      notifyConnectFailure(ScreenCastConnectionError.alreadyConnecting, to: completionHandler)
      return
    }
    // 接続確立済みかチェックします
    guard !isConnected else {
      notifyConnectFailure(ScreenCastConnectionError.alreadyConnected, to: completionHandler)
      return
    }
    isCameraConnectionRequested = isCameraEnabled

    let screenConfiguration = ScreenCastEnvironment.makeScreenCastConfiguration(
      channelId: channelId,
      role: .sendonly,
      videoCodec: videoCodec
    )
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
          // 接続の中から connectionId で解決する。
          // SDK の契約では connected は必ず接続 ID を持つ (欠落は防御的に接続失敗として扱う)。
          guard let connectionId = event.connectionId,
            let screenMediaChannel = self.sora.mediaChannels.first(where: {
              $0.connectionId == connectionId
            })
          else {
            logger.error(
              "[sample] ScreenCastConnectionManager.connect: media channel not found. connectionId: \(event.connectionId ?? "-")"
            )
            self.finishConnect(
              error: ScreenCastConnectionError.missingMediaChannel(connection: "スクリーンキャスト"),
              completionHandler: completionHandler
            )
            return
          }
          self.screenMediaChannel = screenMediaChannel
          logger.info("[sample] connected: \(self.logLabel(for: .screen))")
          guard isCameraEnabled else {
            logger.info("[sample] camera connection skipped: \(self.logLabel(for: .camera))")
            self.finishConnect(error: nil, completionHandler: completionHandler)
            return
          }
          // 画面キャプチャの接続試行は完了し、カメラの接続試行に置き換わります。
          self.connectionTask = nil
          self.connectCamera(
            channelId: channelId,
            videoCodec: videoCodec,
            completionHandler: completionHandler
          )
          return
        case .connectFailed:
          // SDK の契約では connectFailed は必ずエラーを持つ (欠落は防御的に処理する)
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
    connectionTask = sora.connect(configuration: screenConfiguration) { @Sendable _, _ in }
  }

  // カメラの接続を開始します
  private func connectCamera(
    channelId: String,
    videoCodec: VideoCodec,
    completionHandler: (@Sendable (Error?) -> Void)?
  ) {
    let cameraConfiguration = ScreenCastEnvironment.makeCameraConfiguration(
      channelId: channelId,
      role: .sendonly,
      videoCodec: videoCodec
    )
    // 購読の解除は行いません (中止に伴う .connectFailed を受け取って試行中の状態を解放するため)。
    let events = sora.subscribeEvents()
    Task { [weak self] in
      for await event in events {
        guard let self else { return }
        switch event.kind {
        case .connected:
          // SDK の契約では connected は必ず接続 ID を持つ (欠落は防御的に接続失敗として扱う)。
          guard let connectionId = event.connectionId,
            let cameraMediaChannel = self.sora.mediaChannels.first(where: {
              $0.connectionId == connectionId
            })
          else {
            logger.error(
              "[sample] ScreenCastConnectionManager.connectCamera: media channel not found. connectionId: \(event.connectionId ?? "-")"
            )
            self.disconnect()
            self.finishConnect(
              error: ScreenCastConnectionError.missingMediaChannel(connection: "カメラ"),
              completionHandler: completionHandler
            )
            return
          }
          self.cameraMediaChannel = cameraMediaChannel
          logger.info("[sample] connected: \(self.logLabel(for: .camera))")
          self.finishConnect(error: nil, completionHandler: completionHandler)
          return
        case .connectFailed:
          self.disconnect()
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
    connectionTask = sora.connect(configuration: cameraConfiguration) { @Sendable _, _ in }
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

  func disconnect() {
    // 接続試行中であれば試行を中止します。中止すると `.connectFailed` が配送されるため、
    // 購読は残したまま結果を待ちます (結果を受け取るまで次の接続を開始しないため、取り違えは
    // 起こりません)。試行中の状態は finishConnect で解放します。
    connectionTask?.cancel()

    let screenLabel = logLabel(for: .screen)
    let cameraLabel = logLabel(for: .camera)
    let hadCameraChannel = cameraMediaChannel != nil
    let wasCameraConnectionRequested = isCameraConnectionRequested
    if let screenMediaChannel {
      screenMediaChannel.disconnect(error: nil)
    }
    if let cameraMediaChannel {
      cameraMediaChannel.disconnect(error: nil)
    }
    screenMediaChannel = nil
    cameraMediaChannel = nil
    isCameraConnectionRequested = false
    logger.info("[sample] disconnected: \(screenLabel)")
    if hadCameraChannel || wasCameraConnectionRequested {
      logger.info("[sample] disconnected: \(cameraLabel)")
    }
  }

  // 画面キャプチャのログとカメラのログを区別するためのラベル付け
  func logLabel(for kind: ScreenCastConnectionKind) -> String {
    let mediaChannel: MediaChannel?
    switch kind {
    case .screen:
      mediaChannel = screenMediaChannel
    case .camera:
      mediaChannel = cameraMediaChannel
    }

    let channelId = mediaChannel?.configuration.channelId ?? "-"
    // カメラのログだけカメラの接続状況を含めます。
    guard kind == .camera else {
      return "connection_label=\(kind.rawValue), channel_id=\(channelId)"
    }
    return
      "connection_label=\(kind.rawValue), channel_id=\(channelId), camera_requested=\(isCameraConnectionRequested), camera_connected=\(cameraMediaChannel != nil)"
  }
}

enum ScreenCastEnvironment {
  // 接続するサーバーのシグナリング URL
  static var urls: [URL] { Environment.urls }

  // チャネル ID
  static var channelId: String { Environment.channelId }

  // type: connect に含めるメタデータ
  static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }

  // 画面キャプチャの目標 FPS
  static var screenCaptureTargetFPS: Int = 15

  // スクリーンキャスト用の接続設定
  static func makeScreenCastConfiguration(
    channelId: String,
    role: Role,
    videoCodec: VideoCodec
  ) -> Configuration {
    makeConfiguration(
      channelId: channelId,
      role: role,
      videoCodec: videoCodec,
      isCameraEnabled: false,
      initialCameraEnabled: false
    )
  }

  // カメラ用の接続設定
  // カメラは有効状態で接続することを前提としています
  static func makeCameraConfiguration(
    channelId: String,
    role: Role,
    videoCodec: VideoCodec
  ) -> Configuration {
    makeConfiguration(
      channelId: channelId,
      role: role,
      videoCodec: videoCodec,
      isCameraEnabled: true,
      initialCameraEnabled: true
    )
  }

  private static func makeConfiguration(
    channelId: String,
    role: Role,
    videoCodec: VideoCodec,
    isCameraEnabled: Bool,
    initialCameraEnabled: Bool
  ) -> Configuration {
    var configuration = Configuration(urlCandidates: urls, channelId: channelId, role: role)
    configuration.videoCodec = videoCodec
    configuration.audioEnabled = false
    configuration.cameraSettings.isEnabled = isCameraEnabled
    configuration.initialCameraEnabled = initialCameraEnabled
    configuration.initialMicrophoneEnabled = false
    configuration.signalingConnectMetadata = signalingConnectMetadata
    return configuration
  }
}
