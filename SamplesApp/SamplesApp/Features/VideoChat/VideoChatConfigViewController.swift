import Sora
import UIKit

private let logger = SamplesLogger.tagged("VideoChatConfig")

struct H265Params: Encodable {
  let profileId: Int
  let levelId: Int
  let tierFlag: Int
  let txMode: String

  enum CodingKeys: String, CodingKey {
    case profileId = "profile_id"
    case levelId = "level_id"
    case tierFlag = "tier_flag"
    case txMode = "tx_mode"
  }
}

/// チャット接続設定画面です。
class VideoChatConfigViewController: UITableViewController {
  /// チャンネルIDを入力させる欄です。
  @IBOutlet var channelIdTextField: UITextField!

  /// 動画のコーデックを指定するためのコントロールです。
  @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!

  /// 映像ビットレートを選択するためのセルです。
  @IBOutlet var videoBitRatePickerCell: VideoBitRatePickerTableViewCell!

  /// 接続時のカメラ有効設定を切り替えるためのコントロールです。
  @IBOutlet var cameraEnabledOnConnectSegmentedControl: UISegmentedControl!

  /// 開始時のマイク有効設定を切り替えるためのコントロールです。
  @IBOutlet var microphoneEnabledOnConnectSegmentedControl: UISegmentedControl!

  /// データチャンネルシグナリング機能を有効にするためのコントロールです。
  @IBOutlet var dataChannelSignalingSegmentedControl: UISegmentedControl!

  /// データチャンネルシグナリング機能を有効時に WebSocket 切断を許容するためのコントロールです。
  @IBOutlet var ignoreDisconnectWebSocketSegmentedControl: UISegmentedControl!

  @IBOutlet var vp9ProfileIdSegmentedControl: UISegmentedControl!

  @IBOutlet var av1ProfileSegmentedControl: UISegmentedControl!

  @IBOutlet var h264ProfileLevelIdTextField: UITextField!

  /// H.265 プロファイル詳細設定を有効にするためのコントロールです。
  @IBOutlet var h265ParamsEnabledSegmentedControl: UISegmentedControl!

  /// H.265 の profile_id を指定するためのコントロールです。
  @IBOutlet var h265ProfileIdSegmentedControl: UISegmentedControl!

  /// H.265 の level_id を指定するためのコントロールです。
  @IBOutlet var h265LevelIdSegmentedControl: UISegmentedControl!

  /// H.265 の tier_flag を指定するためのコントロールです。
  @IBOutlet var h265TierFlagSegmentedControl: UISegmentedControl!

  /// H.265 の tx_mode を指定するためのコントロールです。
  @IBOutlet var h265TxModeSegmentedControl: UISegmentedControl!

  /// H.265 詳細パラメータ行を表示するかどうかを返す
  private var h265DetailsVisible: Bool {
    h265ParamsEnabledSegmentedControl.selectedSegmentIndex == 1
  }

  /// 接続試行中かどうかを表します。
  var isConnecting = false

  /// 画面起動時の処理を記述します。
  override func viewDidLoad() {
    super.viewDidLoad()
    channelIdTextField.text = VideoChatEnvironment.channelId
    h264ProfileLevelIdTextField.text = ""
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
    guard indexPath.section == 4, indexPath.row == 0 else {
      return
    }

    // チャンネルIDが入力されていない限り無視します。
    guard let channelId = channelIdTextField.text, !channelId.isEmpty else {
      return
    }

    // 接続試行中なら無視します。
    if isConnecting {
      return
    }
    isConnecting = true

    // ユーザーが選択した設定をUIコントロールから取得します。
    let videoCodec: VideoCodec
    switch videoCodecSegmentedControl.selectedSegmentIndex {
    case 0: videoCodec = .default
    case 1: videoCodec = .vp8
    case 2: videoCodec = .vp9
    case 3: videoCodec = .av1
    case 4: videoCodec = .h264
    case 5: videoCodec = .h265
    default: fatalError()
    }

    let dataChannelSignaling: Bool?
    switch dataChannelSignalingSegmentedControl.selectedSegmentIndex {
    case 0: dataChannelSignaling = nil
    case 1: dataChannelSignaling = false
    case 2: dataChannelSignaling = true
    default: fatalError()
    }

    let ignoreDisconnectWebSocket: Bool?
    switch ignoreDisconnectWebSocketSegmentedControl.selectedSegmentIndex {
    case 0: ignoreDisconnectWebSocket = nil
    case 1: ignoreDisconnectWebSocket = false
    case 2: ignoreDisconnectWebSocket = true
    default: fatalError()
    }

    let vp9ProfileId: Int?
    switch vp9ProfileIdSegmentedControl.selectedSegmentIndex {
    case 0: vp9ProfileId = nil
    case 1: vp9ProfileId = 0
    case 2: vp9ProfileId = 1
    case 3: vp9ProfileId = 2
    default: fatalError()
    }

    let av1Profile: Int?
    switch av1ProfileSegmentedControl.selectedSegmentIndex {
    case 0: av1Profile = nil
    case 1: av1Profile = 0
    case 2: av1Profile = 1
    case 3: av1Profile = 2
    default: fatalError()
    }

    let h264ProfileLevelId =
      h264ProfileLevelIdTextField.text!.trimmingCharacters(in: .whitespaces).isEmpty
      ? nil : h264ProfileLevelIdTextField.text!.trimmingCharacters(in: .whitespaces)
    var configuration = Configuration(
      urlCandidates: VideoChatEnvironment.urls, channelId: channelId, role: .sendrecv)
    configuration.videoCodec = videoCodec
    configuration.dataChannelSignaling = dataChannelSignaling
    configuration.ignoreDisconnectWebSocket = ignoreDisconnectWebSocket

    let videoVp9Params = vp9ProfileId != nil ? ["profile_id": vp9ProfileId!] : nil
    configuration.videoVp9Params = videoVp9Params

    let videoAv1Params = av1Profile != nil ? ["profile": av1Profile!] : nil
    configuration.videoAv1Params = videoAv1Params

    let videoH264Params =
      h264ProfileLevelId != nil ? ["profile_level_id": h264ProfileLevelId!] : nil
    let videoH265Params: Encodable?
    if h265DetailsVisible {
      let profileId: Int
      switch h265ProfileIdSegmentedControl.selectedSegmentIndex {
      case 0: profileId = 1  // 既定値
      case 1: profileId = 1
      default: fatalError()
      }
      let levelId: Int
      switch h265LevelIdSegmentedControl.selectedSegmentIndex {
      case 0: levelId = 93  // 既定値
      case 1: levelId = 90
      case 2: levelId = 120
      case 3: levelId = 150
      default: fatalError()
      }
      let tierFlag: Int
      switch h265TierFlagSegmentedControl.selectedSegmentIndex {
      case 0: tierFlag = 0  // 既定値
      case 1: tierFlag = 0
      default: fatalError()
      }
      let txMode: String
      switch h265TxModeSegmentedControl.selectedSegmentIndex {
      case 0: txMode = "SRST"  // 既定値
      case 1: txMode = "SRST"
      default: fatalError()
      }
      videoH265Params = H265Params(
        profileId: profileId,
        levelId: levelId,
        tierFlag: tierFlag,
        txMode: txMode)
    } else {
      videoH265Params = nil
    }
    configuration.videoH264Params = videoH264Params
    configuration.videoH265Params = videoH265Params

    // 接続時カメラ有効設定UIの値から開始時カメラ有効を設定します
    configuration.initialCameraEnabled =
      cameraEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0
    // カメラ自体は後から有効化できるよう、cameraSettings.isEnabled は常に true にします。
    configuration.cameraSettings.isEnabled = true

    // 開始時マイク有効の入力値を configuration に渡します
    configuration.initialMicrophoneEnabled =
      microphoneEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0

    if let videoBitRateValue = videoBitRatePickerCell.selectedBitRate {
      configuration.videoBitRate = videoBitRateValue
    }

    configuration.signalingConnectMetadata = VideoChatEnvironment.signalingConnectMetadata

    // 入力された設定を元にSoraへ接続を行います。
    // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
    // role 引数には .sendrecv を指定します。
    SoraSDKManager.shared.connect(configuration: configuration) { @Sendable [weak self] error in
      // SoraSDKManager のコールバックは任意のスレッドから呼ばれるため、MainActor へ束ねてから実行する
      Task { @MainActor in
        // 接続処理が終了したので false にします。
        self?.isConnecting = false

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
            self?.present(alertController, animated: true, completion: nil)
          }
        } else {
          // errorがnilの場合は、接続に成功しています。
          logger.info("[sample] SoraSDKManager connected.")

          // 次の配信画面に遷移します。
          // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
          // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
          DispatchQueue.main.async {
            guard let self else { return }

            // ConnectセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
            self.performSegue(withIdentifier: "Connect", sender: self)
          }
        }
      }
    }
  }

  /// 配信画面からのUnwind Segueの着地地点として定義してあります。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction func onUnwindToConfig(_ segue: UIStoryboardSegue) {
  }

  /// H.265 プロファイル詳細設定の有効/無効が切り替えられたときの処理です。
  @IBAction func onH265ParamsEnabledChanged(_ sender: UISegmentedControl) {
    if sender.selectedSegmentIndex == 0 {
      h265ProfileIdSegmentedControl.selectedSegmentIndex = 0
      h265LevelIdSegmentedControl.selectedSegmentIndex = 0
      h265TierFlagSegmentedControl.selectedSegmentIndex = 0
      h265TxModeSegmentedControl.selectedSegmentIndex = 0
    }
    tableView.beginUpdates()
    tableView.endUpdates()
  }

  // MARK: - H.265 詳細行の折りたたみ制御

  /// 映像コーデックプロファイル設定セクションのインデックス
  private let codecProfileSection = 3
  /// H.265 詳細行（profile_id, level_id, tier_flag, tx_mode）の行インデックス
  private let h265DetailRowIndices = IndexSet(4...7)

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath)
    -> CGFloat
  {
    if indexPath.section == codecProfileSection
      && h265DetailRowIndices.contains(indexPath.row)
      && !h265DetailsVisible
    {
      return 0
    }
    return super.tableView(tableView, heightForRowAt: indexPath)
  }

}
