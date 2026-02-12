import Sora
import UIKit

private let logger = SamplesLogger.tagged("DataChannelConfig")

/// チャット接続設定画面です。
class DataChannelConfigViewController: UITableViewController {
  // 以下のプロパティは UI コンポーネントを保持します。
  // Main.storyboardから設定されていますので、詳細はそちらをご確認ください。

  /// チャンネルIDを入力するコントロールです。
  @IBOutlet var channelIdTextField: UITextField!

  /// ロールを選択するコントロールです。
  @IBOutlet var roleSegmentedControl: UISegmentedControl!

  /// 映像の配信を指定するコントロールです。
  @IBOutlet var videoEnabledSwitch: UISwitch!

  /// 接続時のカメラ有効設定を切り替えるためのコントロールです。
  @IBOutlet var cameraEnabledOnConnectSegmentedControl: UISegmentedControl!

  /// 開始時のマイク有効設定を切り替えるためのコントロールです。
  @IBOutlet var microphoneEnabledOnConnectSegmentedControl: UISegmentedControl!

  /// 動画のコーデックを指定するためのコントロールです。
  @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!

  /// 音声の配信を指定するコントロールです。
  @IBOutlet var audioEnabledSwitch: UISwitch!

  /// サイマルキャストの配信を指定するコントロールです。
  @IBOutlet var simulcastEnabledSwitch: UISwitch!

  /// サイマルキャスト rid を指定するコントロールです。
  @IBOutlet var simulcastRidSegmentedControl: UISegmentedControl!

  /// スポットライトの配信を指定するコントロールです。
  @IBOutlet var spotlightEnabledSwitch: UISwitch!

  /// スポットライト数を指定するコントロールです。
  @IBOutlet var spotlightNumberSegmentedControl: UISegmentedControl!

  /// スポットライトでフォーカスされた映像の rid を指定するコントロールです。
  @IBOutlet var spotlightFocusRidSegmentedControl: UISegmentedControl!

  /// スポットライトでフォーカスされていない映像の rid を指定するコントロールです。
  @IBOutlet var spotlightUnfocusRidSegmentedControl: UISegmentedControl!

  /// DataChannel メッセージのプロトコルを入力するコントロールです。
  /// プロトコルが空でも送信します。
  @IBOutlet var dataChannelProtocolTextField: UITextField!

  /// DataChannel メッセージのプロトコルの送信を指定するコントロールです。
  /// このスイッチがオンの場合、プロトコルが入力されていても送信しません。
  @IBOutlet var dataChannelProtocolNoSendSwitch: UISwitch!

  /// DataChannel メッセージの方向を指定するコントロールです。
  @IBOutlet var dataChannelDirectionSegmentedControl: UISegmentedControl!

  /// DataChannel メッセージの圧縮を指定するコントロールです。
  @IBOutlet var dataChannelCompressSegmentedControl: UISegmentedControl!

  /// DataChannel メッセージの順序保証を指定するコントロールです。
  @IBOutlet var dataChannelOrderedSegmentedControl: UISegmentedControl!

  /// データチャンネルシグナリング機能を有効時に WebSoket 切断を許容するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var ignoreDisconnectWebSocketSegmentedControl: UISegmentedControl!

  /// DataChannel メッセージでランダムなバイナリを送信するかどうかを指定するコントロールです。
  @IBOutlet var dataChannelRandomBinarySwitch: UISwitch!

  /// 接続試行中かどうかを表します。
  var isConnecting = false

  /// 画面起動時の処理を記述します。
  override func viewDidLoad() {
    super.viewDidLoad()

    channelIdTextField.text = DataChannelEnvironment.channelId
  }

  /// 行がタップされたときの処理を記述します。
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // まず最初にタップされた行の選択状態を解除します。
    tableView.deselectRow(at: indexPath, animated: true)

    // 選択された行が「接続」ボタンでない限り無視します。
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

    let configuration = makeConfiguration(channelId: channelId)

    // Sora 接続処理を実行し、配信画面に遷移します
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

      logger.warning("SoraSDKManager connected.")
      DispatchQueue.main.async {
        self.performSegue(withIdentifier: "Connect", sender: self)
      }
    }
  }

  /// 配信画面からのUnwind Segueの着地地点として定義してあります。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction func onUnwindToConfig(_ segue: UIStoryboardSegue) {
    // 前の画面から戻ってきても、特に処理は何も行いません。
  }

  /// テーブルビューのタップ時に呼ばれます。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction func onTapTableView(_ sender: UITapGestureRecognizer) {
    // テキストフィールドの入力中であれば、表示されているキーボードを閉じます。
    channelIdTextField.endEditing(true)
    dataChannelProtocolTextField.endEditing(true)
  }

  /// テキストフィールドの入力終了時に呼ばれます。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction func onTextFieldDidEnd(_ sender: Any?) {
    // 表示されているキーボードを閉じます。
    channelIdTextField.endEditing(true)
    dataChannelProtocolTextField.endEditing(true)
  }

  private func shouldHandleConnect(for indexPath: IndexPath) -> Bool {
    indexPath.section == 6 && indexPath.row == 0
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
      urlCandidates: DataChannelEnvironment.urls,
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
    configuration.signalingConnectMetadata = DataChannelEnvironment.signalingConnectMetadata
    configuration.dataChannelSignaling = true
    configuration.ignoreDisconnectWebSocket = selectedIgnoreDisconnectWebSocket()

    let direction = selectedDataChannelDirection()
    let compress = selectedDataChannelCompress()
    let ordered = selectedDataChannelOrdered()

    configuration.dataChannels = makeDataChannels(
      direction: direction,
      compress: compress,
      ordered: ordered
    )

    // カメラ自体は後から有効化できるよう、cameraSettings.isEnabled は常に true にします。
    configuration.cameraSettings.isEnabled = true
    // 開始時カメラ有効の入力値を configuration に渡します
    configuration.initialCameraEnabled =
      cameraEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0

    // 開始時マイク有効の入力値を configuration に渡します
    configuration.initialMicrophoneEnabled =
      microphoneEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0

    return configuration
  }

  private func makeDataChannels(
    direction: String,
    compress: Bool?,
    ordered: Bool?
  ) -> [[String: Any]] {
    var dataChannels: [[String: Any]] = []
    for label in DataChannelEnvironment.dataChannelLabels {
      var dataChannel: [String: Any] = ["label": label, "direction": direction]
      if let compress {
        dataChannel["compress"] = compress
      }
      if let ordered {
        dataChannel["ordered"] = ordered
      }
      if !dataChannelProtocolNoSendSwitch.isOn {
        dataChannel["protocol"] = dataChannelProtocolTextField.text ?? ""
      }
      dataChannels.append(dataChannel)
    }
    return dataChannels
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

  private func selectedDataChannelDirection() -> String {
    value(
      from: ["sendonly", "recvonly", "sendrecv"], control: dataChannelDirectionSegmentedControl)
  }

  private func selectedDataChannelCompress() -> Bool? {
    optionalValue(from: [nil, true, false], control: dataChannelCompressSegmentedControl)
  }

  private func selectedDataChannelOrdered() -> Bool? {
    optionalValue(from: [nil, true, false], control: dataChannelOrderedSegmentedControl)
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

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard segue.identifier == "Connect",
      let roomViewController = segue.destination as? DataChannelVideoChatRoomViewController
    else {
      return
    }
    roomViewController.isRandomBinaryEnabled = dataChannelRandomBinarySwitch.isOn
  }
}
