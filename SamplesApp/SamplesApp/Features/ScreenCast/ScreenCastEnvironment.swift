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

  private(set) var screenMediaChannel: MediaChannel?
  private(set) var cameraMediaChannel: MediaChannel?
  private(set) var isCameraConnectionEnabled = true
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
    completionHandler: ((Error?) -> Void)? = nil
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
    isCameraConnectionEnabled = isCameraEnabled

    let screenConfiguration = ScreenCastEnvironment.makeScreenCastConfiguration(
      channelId: channelId,
      role: .sendonly,
      videoCodec: videoCodec
    )
    _ = Sora.shared.connect(configuration: screenConfiguration) { [weak self] mediaChannel, error in
      guard let self else { return }
      if let error {
        self.isConnecting = false
        self.complete(completionHandler, error: error)
        return
      }
      guard let mediaChannel else {
        self.isConnecting = false
        self.complete(
          completionHandler,
          error: ScreenCastConnectionError.missingMediaChannel(connection: "スクリーンキャスト")
        )
        return
      }
      self.screenMediaChannel = mediaChannel
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
        [weak self] mediaChannel, error in
        guard let self else { return }
        self.isConnecting = false
        if let error {
          self.disconnect()
          self.complete(completionHandler, error: error)
          return
        }
        guard let mediaChannel else {
          self.disconnect()
          self.complete(
            completionHandler,
            error: ScreenCastConnectionError.missingMediaChannel(connection: "カメラ")
          )
          return
        }
        self.cameraMediaChannel = mediaChannel
        logger.info("[sample] connected: \(self.logLabel(for: .camera))")
        self.complete(completionHandler, error: nil)
      }
    }
  }

  func disconnect() {
    let screenLabel = logLabel(for: .screen)
    let cameraLabel = logLabel(for: .camera)
    let hadCameraChannel = cameraMediaChannel != nil
    let wasCameraConnectionEnabled = isCameraConnectionEnabled
    if let screenMediaChannel {
      screenMediaChannel.disconnect(error: nil)
    }
    if let cameraMediaChannel {
      cameraMediaChannel.disconnect(error: nil)
    }
    screenMediaChannel = nil
    cameraMediaChannel = nil
    isCameraConnectionEnabled = true
    isConnecting = false
    logger.info("[sample] disconnected: \(screenLabel)")
    if hadCameraChannel || !wasCameraConnectionEnabled {
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
    let cameraEnabled = kind == .camera ? "\(isCameraConnectionEnabled)" : "true"
    return
      "connection_label=\(kind.rawValue), channel_id=\(channelId), camera_enabled=\(cameraEnabled)"
  }

  private func complete(_ completionHandler: ((Error?) -> Void)?, error: Error?) {
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
