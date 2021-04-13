import UIKit
import Sora

/**
 チャット接続設定画面です。
 */
class ConfigViewController: UITableViewController {
    
    @IBOutlet var channelIdLabel: UILabel!

    @IBOutlet var roleButton: UIButton!

    @IBOutlet var multistreamEnabledSwitch: UISwitch!

    @IBOutlet var videoEnabledSwitch: UISwitch!

    @IBOutlet var audioEnabledSwitch: UISwitch!

    @IBOutlet var videoCodecButton: UIButton!
    
    @IBOutlet var videoBitRateButton: UIButton!

    @IBOutlet var audioCodecButton: UIButton!

    @IBOutlet var audioBitRateButton: UIButton!

    @IBOutlet var cameraResolutionButton: UIButton!

    @IBOutlet var cameraFrameRateButton: UIButton!

    @IBOutlet var simulcastEnabledSwitch: UISwitch!

    @IBOutlet var simulcastRidButton: UIButton!

    @IBOutlet var spotlightEnabledSwitch: UISwitch!
    
    @IBOutlet var spotlightNumberButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 各ボタンの設定を行います。
        channelIdLabel.text = SoraSDKManager.channelId
        
        configureRoleButton()
    }
    
    // ロール選択ボタンの設定です。
    func configureRoleButton() {
        roleButton.setTitle("sendrecv", for: .normal)
        let items = UIMenu(options: .displayInline, children: [
            UIAction(title: "sendonly") { _ in
                self.roleButton.setTitle("sendonly", for: .normal)
            },
            UIAction(title: "recvonly") { _ in
                self.roleButton.setTitle("recvonly", for: .normal)
            },
            UIAction(title: "sendrecv") { _ in
                self.roleButton.setTitle("sendrecv", for: .normal)
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
        guard indexPath.section == 1, indexPath.row == 0 else {
            return
        }
        
        // ユーザーが選択した設定をUIコントロールから取得します。
        
        let role: Role
        switch roleButton.currentTitle {
        case "sendonly": role = .sendonly
        case "recvonly": role = .recvonly
        case "sendrecv": role = .sendrecv
        default: fatalError()
        }

        let videoCodec: VideoCodec
        switch videoCodecButton.currentTitle {
        case "未指定": videoCodec = .default
        case "VP9": videoCodec = .vp9
        case "VP8": videoCodec = .vp8
        case "H.264": videoCodec = .h264
        default: fatalError()
        }
        
        let spotlightNumber: Int?
        if let text = spotlightNumberButton.currentTitle {
            spotlightNumber = Int(text)
        } else {
            spotlightNumber = nil
        }
        
        // 入力された設定を元にSoraへ接続を行います。
        // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
        // role 引数には .sendrecv を指定し、マルチストリームを有効にします。
        SoraSDKManager.shared.connect(
            channelId: SoraSDKManager.channelId,
            role: role,
            multistreamEnabled: multistreamEnabledSwitch.isOn,
            videoEnabled: videoEnabledSwitch.isOn,
            audioEnabled: audioEnabledSwitch.isOn,
            videoCodec: videoCodec,
            spotlightEnabled: spotlightEnabledSwitch.isOn,
            spotlightNumber: spotlightNumber
        ) { [weak self] error in
            if let error = error {
                // errorがnilでない場合は、接続に失敗しています。
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
