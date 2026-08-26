import Foundation
@preconcurrency import Sora

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

  private(set) var screenMediaChannel: MediaChannel?
  private(set) var cameraMediaChannel: MediaChannel?
  // 現在の接続セッションでカメラ接続を要求したかどうか
  private(set) var isCameraConnectionRequested = false
  private var isConnecting = false

  var isConnected: Bool {
    screenMediaChannel != nil || cameraMediaChannel != nil
  }

  var isActive: Bool {
    isConnected || isConnecting
  }

  private init() {}

  func connect(
    channelId: String,
    videoCodec: VideoCodec,
    isCameraEnabled: Bool = true,
    completionHandler: (@Sendable (Error?) -> Void)? = nil
  ) {
    // 接続確立中かチェックします
    guard !isConnecting else {
      complete(completionHandler, error: ScreenCastConnectionError.alreadyConnecting)
      return
    }
    // 接続確立済みかチェックします
    guard !isConnected else {
      complete(completionHandler, error: ScreenCastConnectionError.alreadyConnected)
      return
    }
    isConnecting = true
    isCameraConnectionRequested = isCameraEnabled

    let screenConfiguration = ScreenCastEnvironment.makeScreenCastConfiguration(
      channelId: channelId,
      role: .sendonly,
      videoCodec: videoCodec
    )
    _ = Sora.shared.connect(configuration: screenConfiguration) {
      @Sendable [weak self] mediaChannel, error in
      // このクロージャーはデフォルトのアクター隔離 (MainActor) を継承してしまうため、
      // @Sendable にしてアクター隔離を外す。
      // (@Sendable にしないと、SDK がシグナリングスレッドから呼び出した瞬間に
      // Swift 6 の実行時隔離チェックが trap して EXC_BREAKPOINT になる)
      //
      // MediaChannel は非 Sendable のため、Task クロージャーへ送信すると
      // "sending 'mediaChannel' risks causing data races" になる。
      // このコールバックは接続試行ごとに一度だけ呼ばれ、以降 mediaChannel を使わないため
      // nonisolated(unsafe) で渡す。
      // 呼び出し後は Task クロージャー内で MainActor へ移すだけであり、
      // 接続完了コールバックの直後まで SDK が mediaChannel を別スレッドから
      // 並行に変更することもないため、実際のデータ競合は発生しない。
      nonisolated(unsafe) let channel = mediaChannel
      //
      // Sora SDK のコールバックは任意のスレッド (webrtc の signaling スレッド等) から
      // 呼ばれるため、MainActor へ束ねてから状態を更新する
      Task { @MainActor in
        guard let self = self else { return }
        if let error {
          self.isConnecting = false
          self.complete(completionHandler, error: error)
          return
        }
        guard let channel else {
          self.isConnecting = false
          self.complete(
            completionHandler,
            error: ScreenCastConnectionError.missingMediaChannel(connection: "スクリーンキャスト")
          )
          return
        }
        self.screenMediaChannel = channel
        logger.info("[sample] connected: \(self.logLabel(for: .screen))")
        guard isCameraEnabled else {
          self.isConnecting = false
          logger.info("[sample] camera connection skipped: \(self.logLabel(for: .camera))")
          self.complete(completionHandler, error: nil)
          return
        }

        let cameraConfiguration = ScreenCastEnvironment.makeCameraConfiguration(
          channelId: channelId,
          role: .sendonly,
          videoCodec: videoCodec
        )
        _ = Sora.shared.connect(configuration: cameraConfiguration) {
          @Sendable [weak self] mediaChannel, error in
          // MediaChannel は非 Sendable のため、Task クロージャーへ送信すると
          // "sending 'mediaChannel' risks causing data races" になる。
          // このコールバックは接続試行ごとに一度だけ呼ばれ、以降 mediaChannel を使わないため
          // nonisolated(unsafe) で渡す。
          // 呼び出し後は Task クロージャー内で MainActor へ移すだけであり、
          // 接続完了コールバックの直後まで SDK が mediaChannel を別スレッドから
          // 並行に変更することもないため、実際のデータ競合は発生しない。
          nonisolated(unsafe) let channel = mediaChannel
          Task { @MainActor in
            guard let self = self else { return }
            self.isConnecting = false
            if let error {
              self.disconnect()
              self.complete(completionHandler, error: error)
              return
            }
            guard let channel else {
              self.disconnect()
              self.complete(
                completionHandler,
                error: ScreenCastConnectionError.missingMediaChannel(connection: "カメラ")
              )
              return
            }
            self.cameraMediaChannel = channel
            logger.info("[sample] connected: \(self.logLabel(for: .camera))")
            self.complete(completionHandler, error: nil)
          }
        }
      }
    }
  }

  func disconnect() {
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
    isConnecting = false
    logger.info("[sample] disconnected: \(screenLabel)")
    if hadCameraChannel || wasCameraConnectionRequested {
      logger.info("[sample] disconnected: \(cameraLabel)")
    }
  }

  // 画面キャプチャのログかカメラのログが区別するためのラベル付け
  func logLabel(for kind: ScreenCastConnectionKind) -> String {
    let mediaChannel: MediaChannel?
    switch kind {
    case .screen:
      mediaChannel = screenMediaChannel
    case .camera:
      mediaChannel = cameraMediaChannel
    }

    let channelId = mediaChannel?.configuration.channelId ?? "-"
    let cameraRequested = kind == .camera ? "\(isCameraConnectionRequested)" : "true"
    let cameraConnected = kind == .camera ? "\(cameraMediaChannel != nil)" : "true"
    return
      "connection_label=\(kind.rawValue), channel_id=\(channelId), camera_requested=\(cameraRequested), camera_connected=\(cameraConnected)"
  }

  private func complete(_ completionHandler: (@Sendable (Error?) -> Void)?, error: Error?) {
    DispatchQueue.main.async {
      completionHandler?(error)
    }
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
