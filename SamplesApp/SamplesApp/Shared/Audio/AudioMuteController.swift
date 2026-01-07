/// 配信中の音声ミュートの挙動を制御するコントローラーモジュールです
import Sora
import UIKit

/// マイクのミュート状態を管理する Enum です
enum AudioMuteState {
  case enabled
  case softMuted
  case hardMuted

  func next() -> AudioMuteState {
    switch self {
    case .enabled: return .softMuted
    case .softMuted: return .hardMuted
    case .hardMuted: return .enabled
    }
  }

  var symbolName: String {
    switch self {
    case .enabled: return "mic"
    case .softMuted: return "mic.slash"
    case .hardMuted: return "mic.slash.fill"
    }
  }

  // マイクミュートボタンのアクセシビリティラベル
  // ボタンを押した際の次の状態を返します
  var accessibilityLabel: String {
    switch self {
    case .enabled: return "マイクをソフトミュート"
    case .softMuted: return "マイクをハードミュート"
    case .hardMuted: return "マイクを再開"
    }
  }
}

/// マイクのミュート状態を制御するためのコントローラーモジュールです
/// ボタンを押す度に、音声有効 -> 音声ソフトミュート -> 音声ハードミュート -> 音声有効 -> ... のように遷移します
final class AudioMuteController {
  weak var button: UIBarButtonItem? {
    didSet {
      updateButton(to: state)
      updateButtonEnabledState()
    }
  }

  // マイクのミュート状態プロパティです
  private(set) var state: AudioMuteState = .enabled

  // マイクミュートボタンが有効かどうか管理するフラグです
  var isButtonAvailable: Bool = false {
    didSet {
      updateButtonEnabledState()
    }
  }

  // マイクミュート状態が変更処理中かどうか管理するフラグです
  // 現状は同期処理ですが、UI 制御と対称性を保つため持ちます
  var isOperationInProgress: Bool = false {
    didSet {
      updateButtonEnabledState()
    }
  }

  // マイクミュートの現在の状態を返します
  var currentState: AudioMuteState {
    state
  }

  /// ボタンのイメージやラベルをミュート状態に合わせて更新します
  func updateButton(to newState: AudioMuteState) {
    state = newState
    guard let button else { return }
    let symbolName = newState.symbolName
    if let image = UIImage(systemName: symbolName) {
      button.image = image
    } else {
      button.image = UIImage(named: symbolName)
    }
    button.accessibilityLabel = newState.accessibilityLabel
  }

  /// 現在状態から次の状態へ遷移し、MediaChannel へ反映します
  func toggle(using mediaChannel: MediaChannel) {
    apply(to: state.next(), using: mediaChannel)
  }

  /// 指定の状態へ遷移し、MediaChannel へ反映します
  func apply(to nextState: AudioMuteState, using mediaChannel: MediaChannel) {
    switch nextState {
    case .enabled:
      mediaChannel.setAudioSoftMute(false)
      mediaChannel.setAudioHardMute(false)
    case .softMuted:
      mediaChannel.setAudioSoftMute(true)
      mediaChannel.setAudioHardMute(false)
    case .hardMuted:
      // ハードミュートでも不意の音声送出を防ぐため、ソフトミュートも有効にします
      mediaChannel.setAudioSoftMute(true)
      mediaChannel.setAudioHardMute(true)
    }
    updateButton(to: nextState)
  }

  // ミュートボタンが有効かを返します
  // 処理中であれば無効にします
  private func updateButtonEnabledState() {
    guard let button else { return }
    button.isEnabled = isButtonAvailable && !isOperationInProgress
  }
}
