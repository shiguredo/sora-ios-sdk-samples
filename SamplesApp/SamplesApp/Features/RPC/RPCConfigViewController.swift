import Sora
import UIKit

private let logger = SamplesLogger.tagged("RPCConfig")

/// RPC サンプルの接続設定画面です。
class RPCConfigViewController: UITableViewController {
  @IBOutlet var channelIdTextField: UITextField!
  @IBOutlet var roleSegmentedControl: UISegmentedControl!
  @IBOutlet var videoEnabledSwitch: UISwitch!
  @IBOutlet var audioEnabledSwitch: UISwitch!
  @IBOutlet var cameraEnabledOnConnectSegmentedControl: UISegmentedControl!
  @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!
  @IBOutlet var simulcastEnabledSwitch: UISwitch!
  @IBOutlet var simulcastRidSegmentedControl: UISegmentedControl!
  @IBOutlet var spotlightEnabledSwitch: UISwitch!
  @IBOutlet var spotlightNumberSegmentedControl: UISegmentedControl!
  @IBOutlet var spotlightFocusRidSegmentedControl: UISegmentedControl!
  @IBOutlet var spotlightUnfocusRidSegmentedControl: UISegmentedControl!
  @IBOutlet var ignoreDisconnectWebSocketSegmentedControl: UISegmentedControl!

  /// 接続試行中かどうかを表します。
  var isConnecting = false
  /// 接続中に受信した offer の rpc_methods です。
  ///
  /// 書き込みは購読タスク、読み出しは `prepare(for:sender:)` で、どちらも MainActor 上で動くため
  /// 排他は不要です。
  private var offerRPCMethods: [String]?
  // 接続と MediaChannel のイベント購読タスクです。接続のたびに作り直します。
  private var soraEventTask: Task<Void, Never>?
  private var mediaChannelEventTask: Task<Void, Never>?

  override func viewDidLoad() {
    super.viewDidLoad()
    channelIdTextField.text = RPCEnvironment.channelId
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    guard shouldHandleConnect(for: indexPath) else {
      return
    }

    guard let channelId = trimmedChannelId() else {
      return
    }

    guard !isConnecting else {
      return
    }
    isConnecting = true
    offerRPCMethods = nil

    let configuration = makeConfiguration(channelId: channelId)

    // offer の rpc_methods は接続中に受信するため、接続を開始する前に購読を開始します。
    startSignalingEventSubscription()

    SoraSDKManager.shared.connect(configuration: configuration) { @Sendable [weak self] error in
      // コールバックは MainActor 上で呼ばれるが、クロージャーが @Sendable のため MainActor 隔離を
      // 継承しない。MainActor へ束ねてから実行する。
      Task { @MainActor in
        guard let self = self else { return }
        self.isConnecting = false

        if let error {
          logger.warning("SoraSDKManager connection error: \(error)")
          let alertController = UIAlertController(
            title: "接続に失敗しました",
            message: error.localizedDescription,
            preferredStyle: .alert)
          alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
          self.present(alertController, animated: true, completion: nil)
          return
        }

        logger.info("SoraSDKManager connected.")
        self.performSegue(withIdentifier: "Connect", sender: self)
      }
    }
  }

  @IBAction func onUnwindToConfig(_ segue: UIStoryboardSegue) {
    // 前の画面から戻ってきても、特に処理は何も行いません。
  }

  /// 接続中のシグナリングを受信するための購読を開始します。
  private func startSignalingEventSubscription() {
    // MediaChannel は接続の完了前に Sora の管理対象へ追加されるため、
    // mediaChannelAdded を受けてから MediaChannel のイベントを購読します
    // (購読を開始する前に配送されたイベントは届きません)。
    let soraEvents = Sora.shared.subscribeEvents()
    soraEventTask?.cancel()
    soraEventTask = Task { [weak self] in
      for await event in soraEvents {
        guard let self else { return }
        switch event.kind {
        case .mediaChannelAdded:
          // イベントは MediaChannel の実体も接続 ID も運ばないため、接続を試行中の
          // MediaChannel を管理対象の末尾から取る (追加順は SDK の公開ドキュメントには
          // 記載が無く実装依存。接続が直列化されているため取り違えは起きない)。
          guard let mediaChannel = Sora.shared.mediaChannels.last else {
            break
          }
          self.startSignalingJSONSubscription(mediaChannel)
        default:
          break
        }
      }
    }
  }

  /// offer の rpc_methods を取り出すために、MediaChannel のシグナリングを購読します。
  private func startSignalingJSONSubscription(_ mediaChannel: MediaChannel) {
    let events = mediaChannel.subscribeEvents()
    mediaChannelEventTask?.cancel()
    mediaChannelEventTask = Task { [weak self] in
      for await event in events {
        guard let self else { return }
        switch event.kind {
        case .signalingReceivedJSON:
          guard let json = event.signalingJSON,
            let rpcMethods = parseOfferRPCMethods(from: json)
          else {
            break
          }
          self.offerRPCMethods = rpcMethods
        default:
          break
        }
      }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // 画面遷移の直前に開始した購読を終了します (offer の rpc_methods は
    // prepare(for:sender:) で既に受け渡し済みです)。
    soraEventTask?.cancel()
    soraEventTask = nil
    mediaChannelEventTask?.cancel()
    mediaChannelEventTask = nil
  }

  // RPCRoomViewController を表示する直前に、接続中に受け取った
  // offer の rpc_methods を渡して初期表示に使えるようにする。
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard segue.identifier == "Connect",
      let roomViewController = segue.destination as? RPCRoomViewController
    else {
      return
    }
    roomViewController.offerRPCMethods = offerRPCMethods
  }

  @IBAction func onTapTableView(_ sender: UITapGestureRecognizer) {
    channelIdTextField.endEditing(true)
  }

  @IBAction func onTextFieldDidEnd(_ sender: Any?) {
    channelIdTextField.endEditing(true)
  }

  private func shouldHandleConnect(for indexPath: IndexPath) -> Bool {
    indexPath.section == 4 && indexPath.row == 0
  }

  private func trimmedChannelId() -> String? {
    guard let text = channelIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty
    else {
      return nil
    }
    return text
  }

  private func makeConfiguration(channelId: String) -> Configuration {
    var configuration = Configuration(
      urlCandidates: RPCEnvironment.urls,
      channelId: channelId,
      role: selectedRole()
    )
    configuration.videoEnabled = videoEnabledSwitch.isOn
    configuration.videoCodec = selectedVideoCodec()
    configuration.audioEnabled = audioEnabledSwitch.isOn
    configuration.simulcastEnabled = simulcastEnabledSwitch.isOn
    configuration.simulcastRid = selectedSimulcastRid()
    configuration.spotlightEnabled = spotlightEnabledSwitch.isOn ? .enabled : .disabled
    configuration.spotlightNumber = selectedSpotlightNumber()
    configuration.spotlightFocusRid = selectedSpotlightRid(for: spotlightFocusRidSegmentedControl)
    configuration.spotlightUnfocusRid = selectedSpotlightRid(
      for: spotlightUnfocusRidSegmentedControl)
    configuration.signalingConnectMetadata = RPCEnvironment.signalingConnectMetadata
    // RPC 機能を使用するため、DataChannel を使用したシグナリングが必須です。
    configuration.dataChannelSignaling = true
    configuration.ignoreDisconnectWebSocket = selectedIgnoreDisconnectWebSocket()

    let shouldEnableCameraOnConnect =
      cameraEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0
    configuration.cameraSettings.isEnabled = shouldEnableCameraOnConnect

    return configuration
  }

  private func selectedRole() -> Role {
    value(from: [.sendonly, .recvonly, .sendrecv], control: roleSegmentedControl)
  }

  private func selectedVideoCodec() -> VideoCodec {
    value(
      from: [.default, .vp8, .vp9, .av1, .h264, .h265],
      control: videoCodecSegmentedControl
    )
  }

  private func selectedSimulcastRid() -> SimulcastRid? {
    optionalValue(from: [nil, .r0, .r1, .r2], control: simulcastRidSegmentedControl)
  }

  private func selectedSpotlightNumber() -> Int? {
    let index = spotlightNumberSegmentedControl.selectedSegmentIndex
    return index == 0 ? nil : index
  }

  private func selectedSpotlightRid(for control: UISegmentedControl) -> SpotlightRid {
    value(from: [.unspecified, .none, .r0, .r1, .r2], control: control)
  }

  private func selectedIgnoreDisconnectWebSocket() -> Bool? {
    optionalValue(from: [nil, true, false], control: ignoreDisconnectWebSocketSegmentedControl)
  }

  private func value<T>(from values: [T], control: UISegmentedControl) -> T {
    let index = control.selectedSegmentIndex
    precondition(values.indices.contains(index), "Unexpected segmented control index.")
    return values[index]
  }

  private func optionalValue<T>(from values: [T?], control: UISegmentedControl) -> T? {
    let index = control.selectedSegmentIndex
    precondition(values.indices.contains(index), "Unexpected segmented control index.")
    return values[index]
  }
}
