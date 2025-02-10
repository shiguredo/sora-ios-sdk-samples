import Sora
import UIKit

/// チャット接続設定画面です。
class ConfigViewController: UITableViewController {
    // 以下のプロパティは UI コンポーネントを保持します。
    // Main.storyboardから設定されていますので、詳細はそちらをご確認ください。

    /// チャンネルIDを入力するコントロールです。
    @IBOutlet var channelIdTextField: UITextField!

    /// ロールを選択するコントロールです。
    @IBOutlet var roleSegmentedControl: UISegmentedControl!

    /// マルチストリームを指定するコントロールです。
    @IBOutlet var multistreamEnabledSwitch: UISwitch!

    /// 映像の配信を指定するコントロールです。
    @IBOutlet var videoEnabledSwitch: UISwitch!

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

    /**
     画面起動時の処理を記述します。
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        channelIdTextField.text = Environment.channelId
    }

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

        // 以下、ユーザーが選択した設定をUIコントロールから取得します。
        let role: Role
        switch roleSegmentedControl.selectedSegmentIndex {
        case 0: role = .sendonly
        case 1: role = .recvonly
        case 2: role = .sendrecv
        default: fatalError()
        }

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

        let simulcastRid: SimulcastRid?
        switch simulcastRidSegmentedControl.selectedSegmentIndex {
        case 0: simulcastRid = nil
        case 1: simulcastRid = .r0
        case 2: simulcastRid = .r1
        case 3: simulcastRid = .r2
        default: fatalError()
        }

        let spotlightNumber: Int?
        switch spotlightNumberSegmentedControl.selectedSegmentIndex {
        case 0: spotlightNumber = nil
        default: spotlightNumber = spotlightNumberSegmentedControl.selectedSegmentIndex
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

        let ignoreDisconnectWebSocket: Bool?
        switch ignoreDisconnectWebSocketSegmentedControl.selectedSegmentIndex {
        case 0: ignoreDisconnectWebSocket = nil
        case 1: ignoreDisconnectWebSocket = true
        case 2: ignoreDisconnectWebSocket = false
        default: fatalError()
        }

        let messagingDirection: String
        switch dataChannelDirectionSegmentedControl.selectedSegmentIndex {
        case 0: messagingDirection = "sendonly"
        case 1: messagingDirection = "recvonly"
        case 2: messagingDirection = "sendrecv"
        default: fatalError()
        }

        let dataChannelCompress: Bool?
        switch dataChannelCompressSegmentedControl.selectedSegmentIndex {
        case 0: dataChannelCompress = nil
        case 1: dataChannelCompress = true
        case 2: dataChannelCompress = false
        default: fatalError()
        }

        let dataChannelOrdered: Bool?
        switch dataChannelOrderedSegmentedControl.selectedSegmentIndex {
        case 0: dataChannelOrdered = nil
        case 1: dataChannelOrdered = true
        case 2: dataChannelOrdered = false
        default: fatalError()
        }

        SoraSDKManager.shared.dataChannelRandomBinary = dataChannelRandomBinarySwitch.isOn

        // 入力された設定を元にSoraへ接続を行います。
        // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
        // role 引数には .sendrecv を指定し、マルチストリームを有効にします。
        var configuration = Configuration(
            urlCandidates: Environment.urls, channelId: channelId, role: role,
            multistreamEnabled: multistreamEnabledSwitch.isOn)
        configuration.videoEnabled = videoEnabledSwitch.isOn
        configuration.videoCodec = videoCodec
        configuration.audioEnabled = audioEnabledSwitch.isOn
        configuration.simulcastEnabled = simulcastEnabledSwitch.isOn
        configuration.simulcastRid = simulcastRid
        configuration.spotlightEnabled = spotlightEnabledSwitch.isOn ? .enabled : .disabled
        configuration.spotlightNumber = spotlightNumber
        configuration.spotlightFocusRid = spotlightFocusRid
        configuration.spotlightUnfocusRid = spotlightUnfocusRid
        configuration.signalingConnectMetadata = Environment.signalingConnectMetadata

        configuration.dataChannelSignaling = true
        configuration.ignoreDisconnectWebSocket = ignoreDisconnectWebSocket

        // DataChannel ラベルの設定を行います。
        var dataChannels: [[String: Any]] = []
        for label in Environment.dataChannelLabels {
            var dataChannel: [String: Any] = ["label": label, "direction": messagingDirection]
            dataChannel["compress"] = dataChannelCompress
            dataChannel["ordered"] = dataChannelOrdered
            if !dataChannelProtocolNoSendSwitch.isOn {
                dataChannel["protocol"] = dataChannelProtocolTextField.text
            }
            dataChannels.append(dataChannel)
        }
        configuration.dataChannels = dataChannels

        SoraSDKManager.shared.connect(with: configuration) { [weak self] error in
            // 接続処理が終了したので false にします。
            self?.isConnecting = false

            if let error {
                // errorがnilでないばあいは、接続に失敗しています。
                // この場合は、エラー表示をユーザーに返すのが親切です。
                // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
                // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
                NSLog("SoraSDKManager connection error: \(error)")
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

    /**
     テーブルビューのタップ時に呼ばれます。
     詳細はMain.storyboardの設定をご確認ください。
     */
    @IBAction func onTapTableView(_ sender: UITapGestureRecognizer) {
        // テキストフィールドの入力中であれば、表示されているキーボードを閉じます。
        channelIdTextField.endEditing(true)
        dataChannelProtocolTextField.endEditing(true)
    }

    /**
     テキストフィールドの入力終了時に呼ばれます。
     詳細はMain.storyboardの設定をご確認ください。
     */
    @IBAction func onTextFieldDidEnd(_ sender: Any?) {
        // 表示されているキーボードを閉じます。
        channelIdTextField.endEditing(true)
        dataChannelProtocolTextField.endEditing(true)
    }
}
