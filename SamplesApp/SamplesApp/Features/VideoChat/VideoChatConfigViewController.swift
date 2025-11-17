import Sora
import UIKit

/// チャット接続設定画面です。
class VideoChatConfigViewController: UITableViewController {
  /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var channelIdTextField: UITextField!

  /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!

  /// 映像ビットレートを選択するためのセルです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var videoBitRatePickerCell: VideoBitRatePickerTableViewCell!

  /// データチャンネルシグナリング機能を有効にするためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var dataChannelSignalingSegmentedControl: UISegmentedControl!

  /// データチャンネルシグナリング機能を有効時に WebSoket 切断を許容するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var ignoreDisconnectWebSocketSegmentedControl: UISegmentedControl!

  @IBOutlet var vp9ProfileIdSegmentedControl: UISegmentedControl!

  @IBOutlet var av1ProfileSegmentedControl: UISegmentedControl!

  @IBOutlet var h264ProfileLevelIdTextField: UITextField!

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
    configuration.videoH264Params = videoH264Params

    if let videoBitRateValue = videoBitRatePickerCell.selectedBitRate {
      configuration.videoBitRate = videoBitRateValue
    }

    configuration.signalingConnectMetadata = VideoChatEnvironment.signalingConnectMetadata

    // 入力された設定を元にSoraへ接続を行います。
    // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
    // role 引数には .sendrecv を指定します。
    VideoChatSoraSDKManager.shared.connect(
      with: configuration
    ) { [weak self] error in
      // 接続処理が終了したので false にします。
      self?.isConnecting = false

      if let error {
        // errorがnilでないばあいは、接続に失敗しています。
        // この場合は、エラー表示をユーザーに返すのが親切です。
        // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
        // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
        NSLog("[sample] VideoChatSoraSDKManager connection error: \(error)")
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
        NSLog("[sample] VideoChatSoraSDKManager connected.")

        // 次の配信画面に遷移します。
        // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
        // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
        DispatchQueue.main.async {
          // ConnectセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
          self?.performSegue(withIdentifier: "Connect", sender: self)
        }
      }
    }
  }

  /// 配信画面からのUnwind Segueの着地地点として定義してあります。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction func onUnwindToConfig(_ segue: UIStoryboardSegue) {
    // 前の画面から戻ってきても、特に処理は何も行いません。
  }

}
