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
  // onReceiveSignaling と prepare(for:sender:) が異なるスレッドで呼ばれる可能性があるため、
  // offerRPCMethods へのアクセスは stateQueue 経由に限定する。
  private let stateQueue = DispatchQueue(label: "jp.shiguredo.samples.rpc-config.state")
  private var _offerRPCMethods: [String]?
  private var offerRPCMethods: [String]? {
    get {
      stateQueue.sync {
        _offerRPCMethods
      }
    }
    set {
      stateQueue.sync {
        _offerRPCMethods = newValue
      }
    }
  }

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

    var configuration = makeConfiguration(channelId: channelId)
    configuration.mediaChannelHandlers.onReceiveSignaling = { [weak self] signaling in
      guard case .offer(let offer) = signaling else {
        return
      }
      self?.offerRPCMethods = offer.rpcMethods
    }

    SoraSDKManager.shared.connect(configuration: configuration) { [weak self] error in
      guard let self = self else { return }
      self.isConnecting = false

      if let error {
        logger.warning("SoraSDKManager connection error: \(error)")
        DispatchQueue.main.async {
          let alertController = UIAlertController(
            title: "接続に失敗しました",
            message: error.localizedDescription,
            preferredStyle: .alert)
          alertController.addAction(
            UIAlertAction(title: "OK", style: .cancel, handler: nil))
          self.present(alertController, animated: true, completion: nil)
        }
        return
      }

      logger.info("SoraSDKManager connected.")
      DispatchQueue.main.async {
        self.performSegue(withIdentifier: "Connect", sender: self)
      }
    }
  }

  @IBAction func onUnwindToConfig(_ segue: UIStoryboardSegue) {
    // 前の画面から戻ってきても、特に処理は何も行いません。
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
