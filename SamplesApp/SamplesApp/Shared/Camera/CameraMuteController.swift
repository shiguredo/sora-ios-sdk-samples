/// 配信中のカメラミュートの挙動を制御するコントローラーモジュールです
import AVFoundation
import Sora
import UIKit

/// カメラのミュート状態を管理する Enum です
enum CameraMuteState {
  case recording
  case softMuted
  case hardMuted

  func next() -> CameraMuteState {
    switch self {
    case .recording: return .softMuted
    case .softMuted: return .hardMuted
    case .hardMuted: return .recording
    }
  }

  var symbolName: String {
    switch self {
    case .recording: return "video"
    case .softMuted: return "video.slash"
    case .hardMuted: return "video.slash.fill"
    }
  }

  // カメラミュートボタンのアクセシビリティラベル
  // ボタンを押した際の次の状態を返します
  var accessibilityLabel: String {
    switch self {
    case .recording: return "カメラをソフトミュート"
    case .softMuted: return "カメラをハードミュート"
    case .hardMuted: return "カメラを再開"
    }
  }
}

/// カメラのミュート状態を制御するためのコントローラーモジュールです
/// ボタンを押す度に、カメラ有効 -> ソフトミュート -> ハードミュート -> カメラ有効 -> ... のように遷移します
final class CameraMuteController {
  weak var button: UIBarButtonItem? {
    didSet {
      updateButton(to: state)
      updateButtonEnabledState()
    }
  }
  // 前面背面カメラ切り替えボタンです
  // ハードミュート中は無効化する制御のため
  // ここでプロパティとして持ちます
  weak var flipButton: UIBarButtonItem? {
    didSet {
      updateFlipButtonState()
    }
  }

  // カメラのミュート状態プロパティです
  private(set) var state: CameraMuteState = .recording

  // カメラミュートボタンが有効かどうか管理するフラグです
  var isButtonAvailable: Bool = false {
    didSet {
      updateButtonEnabledState()
    }
  }

  // カメラミュート状態が変更処理中かどうか管理するフラグです
  var isOperationInProgress: Bool = false {
    didSet {
      updateButtonEnabledState()
    }
  }

  var cameraCapture: CameraVideoCapturer?

  // カメラミュートの現在の状態を返します
  var currentState: CameraMuteState {
    state
  }

  /// 接続設定のカメラ設定と upstream から CameraVideoCapturer を新規生成するヘルパーです。
  /// 起動に必要なデバイス/フォーマット/フレームレートを解決できなかった場合は nil を返します。
  static func createCapturerForStart(
    using cameraSettings: CameraSettings?,
    upstream: MediaStream
  ) -> (capturer: CameraVideoCapturer, format: AVCaptureDevice.Format, frameRate: Int)? {
    let settings = cameraSettings ?? .default
    let device =
      CameraVideoCapturer.device(for: settings.position)
      ?? CameraVideoCapturer.devices.first
    guard let device else {
      return nil
    }
    guard
      let format = CameraVideoCapturer.format(
        width: settings.resolution.width,
        height: settings.resolution.height,
        for: device,
        frameRate: settings.frameRate),
      let frameRate = CameraVideoCapturer.maxFrameRate(settings.frameRate, for: format)
    else {
      return nil
    }
    let capturer = CameraVideoCapturer(device: device)
    capturer.stream = upstream
    return (capturer, format, frameRate)
  }

  /// ボタンのイメージやラベルをミュート状態に合わせて更新します
  func updateButton(to newState: CameraMuteState) {
    state = newState
    updateFlipButtonState()
    guard let button else { return }
    let symbolName = newState.symbolName
    // ボタンのアイコンイメージを取得します
    // System カタログから取得を試みて、なければ名前指定で取得します
    if let image = UIImage(systemName: symbolName) {
      button.image = image
    } else {
      button.image = UIImage(named: symbolName)
    }
    button.accessibilityLabel = newState.accessibilityLabel
  }

  // ミュートボタンが有効かを返します
  // 処理中であれば無効にします
  private func updateButtonEnabledState() {
    guard let button else { return }
    button.isEnabled = isButtonAvailable && !isOperationInProgress
  }

  // カメラのハードミュート中はカメラ切り替えボタンを無効化します
  private func updateFlipButtonState() {
    flipButton?.isEnabled = state != .hardMuted
  }

  // カメラミュート状態切り替えエラー時に、直前の状態に復帰させるための関数です。
  // capturer は「復帰後も生存させたい CameraVideoCapturer」を呼び出し側が渡します。
  func restoreState(
    to previousState: CameraMuteState,
    upstream: MediaStream,
    capturer: CameraVideoCapturer?
  ) {
    updateButton(to: previousState)
    switch previousState {
    case .recording:
      upstream.videoEnabled = true
    case .softMuted:
      upstream.videoEnabled = false
    case .hardMuted:
      upstream.videoEnabled = false
    }
    // 状態遷移の失敗でキャプチャが動作中のままになる可能性があるため、
    // 呼び出し側が渡した参照があれば保持して生存期間を安定させます。
    cameraCapture = capturer
  }
}
