import Sora
import UIKit

/**
 チャット接続設定画面です。
 */
class ConfigViewController: UITableViewController {
    /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var channelIdTextField: UITextField!

    /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!

    /// アクティブ配信数を指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var spotlightNumberSegmentedControl: UISegmentedControl!

    /// フォーカスされた映像の Rid を指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var spotlightFocusRidSegmentedControl: UISegmentedControl!

    /// フォーカスされた映像の Rid を指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var spotlightUnfocusRidSegmentedControl: UISegmentedControl!

    /// 接続試行中かどうかを表します。
    var isConnecting = false

    override func viewDidLoad() {
        super.viewDidLoad()

        channelIdTextField.text = Environment.channelId
    }

    /// サイマルキャスト
    @IBOutlet var simulcastSegmentedControl: UISegmentedControl!

    /// データチャンネルシグナリング機能を有効にするためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var dataChannelSignalingSegmentedControl: UISegmentedControl!

    /// データチャンネルシグナリング機能を有効時に WebSoket 切断を許容するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var ignoreDisconnectWebSocketSegmentedControl: UISegmentedControl!

    /**
     行がタップされたときの処理を記述します。
     */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // まず最初にタップされた行の選択状態を解除します。
        tableView.deselectRow(at: indexPath, animated: true)

        // 選択された行が「接続」ボタンでない限り無視します。
        guard indexPath.section == 6, indexPath.row == 0 else {
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
        case 0: videoCodec = .vp8
        case 1: videoCodec = .vp9
        case 2: videoCodec = .h264
        case 3: videoCodec = .av1
        default: fatalError()
        }

        let spotlightFocusRid: SpotlightRid
        switch spotlightFocusRidSegmentedControl.selectedSegmentIndex {
        case 0: spotlightFocusRid = .unspecified
        case 1: spotlightFocusRid = .none
        case 2: spotlightFocusRid = .r0
        case 3: spotlightFocusRid = .r1
        case 4: spotlightFocusRid = .r2
        default: fatalError()
        }

        let spotlightUnfocusRid: SpotlightRid
        switch spotlightUnfocusRidSegmentedControl.selectedSegmentIndex {
        case 0: spotlightUnfocusRid = .unspecified
        case 1: spotlightUnfocusRid = .none
        case 2: spotlightUnfocusRid = .r0
        case 3: spotlightUnfocusRid = .r1
        case 4: spotlightUnfocusRid = .r2
        default: fatalError()
        }

        let spotlightNumber: Int?
        if spotlightNumberSegmentedControl.selectedSegmentIndex == 0 {
            spotlightNumber = nil
        } else {
            spotlightNumber = spotlightNumberSegmentedControl.selectedSegmentIndex
        }

        let simulcast: Bool
        switch simulcastSegmentedControl.selectedSegmentIndex {
        case 0: simulcast = false
        case 1: simulcast = true
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

        // 入力された設定を元にSoraへ接続を行います。
        // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
        // role 引数には .sendrecv を指定し、マルチストリームを有効にします。
        SoraSDKManager.shared.connect(
            channelId: channelId,
            videoCodec: videoCodec,
            spotlightFocusRid: spotlightFocusRid,
            spotlightUnfocusRid: spotlightUnfocusRid,
            spotlightNumber: spotlightNumber,
            simulcast: simulcast,
            dataChannelSignaling: dataChannelSignaling,
            ignoreDisconnectWebSocket: ignoreDisconnectWebSocket
        ) { [weak self] error in
            // 接続処理が終了したので false にします。
            self?.isConnecting = false

            if let error = error {
                // errorがnilでないばあいは、接続に失敗しています。
                // この場合は、エラー表示をユーザーに返すのが親切です。
                // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
                // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
                NSLog("[sample] SoraSDKManager connection error: \(error)")
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "接続に失敗しました",
                                                            message: error.localizedDescription,
                                                            preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                }
            } else {
                // errorがnilの場合は、接続に成功しています。
                NSLog("[sample] SoraSDKManager connected.")

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

    /**
     配信画面からのUnwind Segueの着地地点として定義してあります。
     詳細はMain.storyboardの設定をご確認ください。
     */
    @IBAction func onUnwindToConfig(_ segue: UIStoryboardSegue) {
        // 前の画面から戻ってきても、特に処理は何も行いません。
    }
}
