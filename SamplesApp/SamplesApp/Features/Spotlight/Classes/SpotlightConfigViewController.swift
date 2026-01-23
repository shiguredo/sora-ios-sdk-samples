import Sora
import UIKit

private let logger = SamplesLogger.tagged("SpotlightConfig")

/// チャット接続設定画面です。
class SpotlightConfigViewController: UITableViewController {
  /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var channelIdTextField: UITextField!

  /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!

  /// 映像ビットレートを選択するためのセルです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var videoBitRatePickerCell: VideoBitRatePickerTableViewCell!

  /// 接続時のカメラ有効設定を切り替えるためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var cameraEnabledOnConnectSegmentedControl: UISegmentedControl!

  /// 開始時のマイク有効設定を切り替えるためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var microphoneEnabledOnConnectSegmentedControl: UISegmentedControl!

  /// アクティブ配信数を指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var spotlightNumberSegmentedControl: UISegmentedControl!

  /// フォーカスされた映像の Rid を指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var spotlightFocusRidSegmentedControl: UISegmentedControl!

  /// フォーカスされた映像の Rid を指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var spotlightUnfocusRidSegmentedControl: UISegmentedControl!

  /// サイマルキャスト
  @IBOutlet var simulcastSegmentedControl: UISegmentedControl!

  /// データチャンネルシグナリング機能を有効にするためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var dataChannelSignalingSegmentedControl: UISegmentedControl!

  /// データチャンネルシグナリング機能を有効時に WebSoket 切断を許容するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var ignoreDisconnectWebSocketSegmentedControl: UISegmentedControl!

  /// 接続試行中かどうかを表します。
  var isConnecting = false

  override func viewDidLoad() {
    super.viewDidLoad()

    channelIdTextField.text = SpotlightEnvironment.channelId
  }

  /// 行がタップされたときの処理を記述します。
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // まず最初にタップされた行の選択状態を解除します。
    tableView.deselectRow(at: indexPath, animated: true)

    if indexPath.section == 1, indexPath.row == 1 {
      videoBitRatePickerCell.focusPicker()
      return
    }

    // 選択された行が「接続」ボタンでない限り無視します。
    guard shouldHandleConnect(for: indexPath) else {
      return
    }

    // チャンネルIDが入力されていない限り無視します。
    guard let channelId = trimmedChannelId() else {
      return
    }

    // 接続試行中なら無視します。
    guard !isConnecting else {
      return
    }
    isConnecting = true

    // 入力された設定を元にSoraへ接続を行います。
    // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
    // role 引数には .sendrecv を指定します。
    var configuration = SpotlightEnvironment.makeConfiguration(
      channelId: channelId,
      videoCodec: selectedVideoCodec(),
      spotlightFocusRid: selectedSpotlightRid(for: spotlightFocusRidSegmentedControl),
      spotlightUnfocusRid: selectedSpotlightRid(for: spotlightUnfocusRidSegmentedControl),
      spotlightNumber: selectedSpotlightNumber(),
      simulcast: selectedSimulcast(),
      dataChannelSignaling: selectedDataChannelSignaling(),
      ignoreDisconnectWebSocket: selectedIgnoreDisconnectWebSocket(),
      videoBitRate: videoBitRatePickerCell.selectedBitRate
    )
    // 開始時カメラ有効の入力値を configuration に渡します
    configuration.initialCameraEnabled =
      cameraEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0

    // 開始時マイク有効の入力値を configuration に渡します
    configuration.initialMicrophoneEnabled =
      microphoneEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0

    SoraSDKManager.shared.connect(configuration: configuration) { [weak self] error in
      guard let self = self else { return }
      // 接続処理が終了したので false にします。
      self.isConnecting = false

      if let error {
        // errorがnilでないばあいは、接続に失敗しています。
        // この場合は、エラー表示をユーザーに返すのが親切です。
        // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
        // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
        logger.warning("[sample] SoraSDKManager connection error: \(error)")
        DispatchQueue.main.async {
          let alertController = UIAlertController(
            title: "接続に失敗しました",
            message: error.localizedDescription,
            preferredStyle: .alert)
          alertController.addAction(
            UIAlertAction(title: "OK", style: .cancel, handler: nil))
          self.present(alertController, animated: true, completion: nil)
        }
      } else {
        // errorがnilの場合は、接続に成功しています。
        logger.info("[sample] SoraSDKManager connected.")

        // 次の配信画面に遷移します。
        // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
        // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
        DispatchQueue.main.async {
          // ConnectセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
          self.performSegue(withIdentifier: "Connect", sender: self)
        }
      }
    }
  }

  /// 配信画面からのUnwind Segueの着地地点として定義してあります。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction func onUnwindToConfig(_ segue: UIStoryboardSegue) {
    // 前の画面から戻ってきても、特に処理は何も行いません。
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

  private func selectedVideoCodec() -> VideoCodec {
    value(
      from: [.default, .vp8, .vp9, .av1, .h264, .h265],
      control: videoCodecSegmentedControl
    )
  }

  private func selectedSpotlightRid(for control: UISegmentedControl) -> SpotlightRid {
    value(from: [.unspecified, .none, .r0, .r1, .r2], control: control)
  }

  private func selectedSpotlightNumber() -> Int? {
    let index = spotlightNumberSegmentedControl.selectedSegmentIndex
    return index == 0 ? nil : index
  }

  private func selectedSimulcast() -> Bool {
    value(from: [false, true], control: simulcastSegmentedControl)
  }

  private func selectedDataChannelSignaling() -> Bool? {
    optionalValue(from: [nil, false, true], control: dataChannelSignalingSegmentedControl)
  }

  private func selectedIgnoreDisconnectWebSocket() -> Bool? {
    optionalValue(
      from: [nil, false, true],
      control: ignoreDisconnectWebSocketSegmentedControl
    )
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
      let roomViewController = segue.destination as? SpotlightVideoChatRoomViewController
    else {
      return
    }
  }

}
