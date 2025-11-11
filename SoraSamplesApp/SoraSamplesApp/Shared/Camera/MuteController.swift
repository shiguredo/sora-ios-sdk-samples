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
/// ボタンを押す度に、カメラ有効 -> ソフトミュート -> ハードミュート -> カメラ有効 のように
final class CameraMuteController {
  weak var button: UIBarButtonItem? {
    didSet {
      updateButton(to: state)
      updateButtonEnabledState()
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

  /// ボタンのイメージやラベルをミュート状態に合わせて更新します
  func updateButton(to newState: CameraMuteState) {
    state = newState
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

  // カメラミュート状態切り替えエラー時に、直前の状態に復帰させるための関数です
  func restoreState(
    to previousState: CameraMuteState,
    upstream: MediaStream,
    capturer: CameraVideoCapturer?
  ) {
    updateButton(to: previousState)
    switch previousState {
    case .recording:
      upstream.videoEnabled = true
      cameraCapture = nil
    case .softMuted:
      upstream.videoEnabled = false
      cameraCapture = nil
    case .hardMuted:
      upstream.videoEnabled = false
      cameraCapture = capturer
    }
  }
}
