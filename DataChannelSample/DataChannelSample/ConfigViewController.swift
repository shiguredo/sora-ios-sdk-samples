import Sora
import UIKit

/**
 チャット接続設定画面です。
 */
class ConfigViewController: UITableViewController {
    /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var channelIdTextField: UITextField!

    @IBOutlet var roleSegmentedControl: UISegmentedControl!

    @IBOutlet var videoEnabledSwitch: UISwitch!

    /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!

    @IBOutlet var audioEnabledSwitch: UISwitch!

    @IBOutlet var simulcastEnabledSwitch: UISwitch!

    @IBOutlet var simulcastRidSegmentedControl: UISegmentedControl!

    @IBOutlet var spotlightEnabledSwitch: UISwitch!

    @IBOutlet var spotlightNumberSegmentedControl: UISegmentedControl!

    @IBOutlet var spotlightFocusRidSegmentedControl: UISegmentedControl!

    @IBOutlet var spotlightUnfocusRidSegmentedControl: UISegmentedControl!

    @IBOutlet var dataChannelLabelTextField: UITextField!

    @IBOutlet var dataChannelDirectionSegmentedControl: UISegmentedControl!

    /// データチャンネルシグナリング機能を有効時に WebSoket 切断を許容するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var ignoreDisconnectWebSocketSwitch: UISwitch!

    /**
     画面起動時の処理を記述します。
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        channelIdTextField.text = "sora"
    }

    /**
     行がタップされたときの処理を記述します。
     */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // まず最初にタップされた行の選択状態を解除します。
        tableView.deselectRow(at: indexPath, animated: true)

        // 選択された行が「接続」ボタンでない限り無視します。
        guard indexPath.section == 5, indexPath.row == 0 else {
            return
        }

        // チャンネルIDが入力されていない限り無視します。
        guard let channelId = channelIdTextField.text, !channelId.isEmpty else {
            return
        }

        guard let dataChannelLabel = dataChannelLabelTextField.text, !channelId.isEmpty else {
            return
        }

        let role: Role
        switch roleSegmentedControl.selectedSegmentIndex {
        case 0: role = .sendonly
        case 1: role = .recvonly
        case 2: role = .sendrecv
        default: fatalError()
        }

        // ユーザーが選択した設定をUIコントロールから取得します。
        let videoCodec: VideoCodec
        switch videoCodecSegmentedControl.selectedSegmentIndex {
        case 0: videoCodec = .default
        case 1: videoCodec = .vp9
        case 2: videoCodec = .vp8
        case 3: videoCodec = .h264
        default: fatalError()
        }

        let simulcastRid: SimulcastRid?
        switch simulcastRidSegmentedControl.selectedSegmentIndex {
        case 0: simulcastRid = nil
        case 1: simulcastRid = .r0
        case 2: simulcastRid = .r1
        case 3: simulcastRid = .r2
        default: fatalError()
        }

        let spotlightNumber = spotlightNumberSegmentedControl.selectedSegmentIndex

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

        // 入力された設定を元にSoraへ接続を行います。
        // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
        // role 引数には .sendrecv を指定し、マルチストリームを有効にします。
        var configuration = Configuration(url: Environment.targetURL, channelId: channelId, role: role, multistreamEnabled: true)
        configuration.videoEnabled = videoEnabledSwitch.isOn
        configuration.videoCodec = videoCodec
        configuration.audioEnabled = audioEnabledSwitch.isOn
        configuration.simulcastEnabled = simulcastEnabledSwitch.isOn
        configuration.simulcastRid = simulcastRid
        configuration.spotlightEnabled = spotlightEnabledSwitch.isOn ? .enabled : .disabled
        configuration.spotlightNumber = spotlightNumber
        configuration.spotlightFocusRid = spotlightFocusRid
        configuration.spotlightUnfocusRid = spotlightUnfocusRid

        SoraSDKManager.shared.connect(with: configuration) { [weak self] error in
            if let error = error {
                // errorがnilでないばあいは、接続に失敗しています。
                // この場合は、エラー表示をユーザーに返すのが親切です。
                // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
                // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
                NSLog("SoraSDKManager connection error: \(error)")
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "接続に失敗しました",
                                                            message: error.localizedDescription,
                                                            preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                }
            } else {
                // errorがnilの場合は、接続に成功しています。
                NSLog("SoraSDKManager connected.")

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

    @IBAction func onTapTableView(_ sender: UITapGestureRecognizer) {
        channelIdTextField.endEditing(true)
        dataChannelLabelTextField.endEditing(true)
    }

    @IBAction func onTextFieldDidEnd(_ sender: Any?) {
        channelIdTextField.endEditing(true)
        dataChannelLabelTextField.endEditing(true)
    }
}
