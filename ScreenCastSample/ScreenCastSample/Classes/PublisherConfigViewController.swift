import Sora
import UIKit

/// 配信設定画面です。
class PublisherConfigViewController: UITableViewController {
  /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var channelIdTextField: UITextField!
  /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!

  /// 接続試行中かどうかを表します。
  var isConnecting = false

  /// 画面起動時の処理を記述します。
  override func viewDidLoad() {
    super.viewDidLoad()

    channelIdTextField.text = Environment.channelId
  }

  /// 行がタップされたときの処理を記述します。
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // まず最初にタップされた行の選択状態を解除します。
    tableView.deselectRow(at: indexPath, animated: true)

    // 選択された行が「接続」ボタンでない限り無視します。
    guard indexPath.section == 2, indexPath.row == 0 else {
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

    // 入力された設定を元にSoraへ接続を行います。
    // この画面からは配信側に接続を行うため、role引数には .publisher を指定しています。
    // また今回のサンプルアプリでは、デフォルトのカメラ映像のキャプチャではなく、ReplayKit経由で取得したスクリーンキャストを使用したいため、
    // videoCapturerOptionをカスタムに設定しておきます。
    SoraSDKManager.shared.connect(
      channelId: channelId,
      role: .sendonly,
      videoCodec: videoCodec
    ) { [weak self] error in
      // 接続処理が終了したので false にします。
      self?.isConnecting = false

      if let error {
        // errorがnilでないばあいは、接続に失敗しています。
        // この場合は、エラー表示をユーザーに返すのが親切です。
        // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
        // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
        NSLog("[sample] SoraSDKManager connection error: \(error)")
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
        NSLog("[sample] SoraSDKManager connected.")

        // 接続が完了したので、ゲーム画面に戻ります。
        // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
        // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
        DispatchQueue.main.async {
          // ConnectセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
          self?.performSegue(withIdentifier: "Connect", sender: self)
        }
      }
    }
  }
}
