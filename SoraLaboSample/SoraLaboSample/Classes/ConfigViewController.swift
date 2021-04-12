import UIKit
import Sora

/**
 チャット接続設定画面です。
 */
class ConfigViewController: UITableViewController {
    
    /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var channelIdTextField: UITextField!
    
    @IBOutlet var roleButton: UIButton!

    /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!
    
    @IBOutlet var spotlightSwitch: UISwitch!
    
    @IBOutlet var spotlightLegacySwitch: UISwitch!
    
    @IBOutlet var activeSpeakerLimitSegmentedControl: UISegmentedControl!

    var configuration: Configuration!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 接続設定の準備を行います。
        configuration = Configuration(url: SoraSDKManager.targetURL, channelId: SoraSDKManager.channelId, role: .sendrecv, multistreamEnabled: true)

        // 各ボタンの設定を行います。
        configureRoleButton()
    }
    
    // ロール選択ボタンの設定です。
    func configureRoleButton() {
        roleButton.setTitle("sendrecv", for: .normal)
        let items = UIMenu(options: .displayInline, children: [
            UIAction(title: "sendonly") { _ in
                self.roleButton.setTitle("sendonly", for: .normal)
                self.configuration.role = .sendonly
            },
            UIAction(title: "recvonly") { _ in
                self.roleButton.setTitle("recvonly", for: .normal)
                self.configuration.role = .recvonly
            },
            UIAction(title: "sendrecv") { _ in
                self.roleButton.setTitle("sendrecv", for: .normal)
                self.configuration.role = .sendrecv
            },
        ])
        roleButton.menu = UIMenu(title: "", children: [items])
        roleButton.showsMenuAsPrimaryAction = true
    }
    
    /**
     行がタップされたときの処理を記述します。
     */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // まず最初にタップされた行の選択状態を解除します。
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 選択された行が「接続」ボタンでない限り無視します。
        guard indexPath.section == 3, indexPath.row == 0 else {
            return
        }
        
        // チャンネルIDが入力されていない限り無視します。
        guard let channelId = channelIdTextField.text, !channelId.isEmpty else {
            return
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
        
        var spotlight: Configuration.Spotlight
        if spotlightSwitch.isOn {
            spotlight = spotlightLegacySwitch.isOn ? .legacy : .enabled
        } else {
            spotlight = .disabled
        }
        
        let activeSpeakerLimit: Int = activeSpeakerLimitSegmentedControl.selectedSegmentIndex + 1
        
        // 入力された設定を元にSoraへ接続を行います。
        // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
        // role 引数には .sendrecv を指定し、マルチストリームを有効にします。
        SoraSDKManager.shared.connect(
            channelId: channelId,
            role: .sendrecv,
            multistreamEnabled: true,
            videoCodec: videoCodec,
            spotlight: spotlight,
            activeSpeakerLimit: activeSpeakerLimit
        ) { [weak self] error in
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
    
}
