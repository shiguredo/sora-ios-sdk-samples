import Sora
import UIKit

private let logger = SamplesLogger.tagged("ScreenCastConfig")

/// 配信設定画面です。
class ScreenCastConfigViewController: UITableViewController {
  /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var channelIdTextField: UITextField!
  /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!
  /// 画面キャプチャのFPSを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet var targetFPSSegmentedControl: UISegmentedControl!
  /// 接続時にカメラ配信を有効にするか指定するためのコントロールです。
  @IBOutlet var cameraEnabledOnConnectSegmentedControl: UISegmentedControl!

  /// 接続試行中かどうかを表します。
  var isConnecting = false

  /// 画面起動時の処理を記述します。
  override func viewDidLoad() {
    super.viewDidLoad()

    channelIdTextField.text = ScreenCastEnvironment.channelId
    cameraEnabledOnConnectSegmentedControl.selectedSegmentIndex = 0
    if let index = [15, 30, 60].firstIndex(of: ScreenCastEnvironment.screenCaptureTargetFPS) {
      targetFPSSegmentedControl.selectedSegmentIndex = index
    } else {
      targetFPSSegmentedControl.selectedSegmentIndex = 0
    }
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

    // 画面キャプチャ開始時に利用する目標 FPS を更新します。
    ScreenCastEnvironment.screenCaptureTargetFPS = selectedTargetFPS()

    let isCameraEnabledOnConnect = cameraEnabledOnConnectSegmentedControl.selectedSegmentIndex == 0

    // 入力された設定を元に、スクリーンキャスト接続と(必要に応じて)カメラ接続を作成します。
    ScreenCastConnectionManager.shared.connect(
      channelId: channelId,
      videoCodec: videoCodec,
      isCameraEnabled: isCameraEnabledOnConnect
    ) {
      @Sendable [weak self] error in
      // ScreenCastConnectionManager のコールバックは任意のスレッドから呼ばれるため、
      // MainActor へ束ねてから実行する
      Task { @MainActor in
        // 接続処理が終了したので false にします。
        self?.isConnecting = false

        if let error {
          // errorがnilでないばあいは、接続に失敗しています。
          // この場合は、エラー表示をユーザーに返すのが親切です。
          // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
          // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
          logger.warning("[sample] ScreenCastConnectionManager connection error: \(error)")
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
          logger.info(
            "[sample] ScreenCastConnectionManager connected. \(ScreenCastConnectionManager.shared.logLabel(for: .screen))"
          )
          if isCameraEnabledOnConnect {
            logger.info(
              "[sample] ScreenCastConnectionManager connected. \(ScreenCastConnectionManager.shared.logLabel(for: .camera))"
            )
          }

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

  private func selectedTargetFPS() -> Int {
    switch targetFPSSegmentedControl.selectedSegmentIndex {
    case 0: return 15
    case 1: return 30
    case 2: return 60
    default: fatalError()
    }
  }
}
