import UIKit
import Sora

/**
 配信設定画面です。
 */
class PublisherConfigViewController: UITableViewController {
    
    /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var channelIdTextField: UITextField!
    /// 動画のコーデックを指定するためのコントロールです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var videoCodecSegmentedControl: UISegmentedControl!
    
    /**
     行がタップされたときの処理を記述します。
     */
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
        
        // ユーザーが選択した設定をUIコントロールから取得します。
        let videoCodec: VideoCodec
        switch videoCodecSegmentedControl.selectedSegmentIndex {
        case 0: videoCodec = .default
        case 1: videoCodec = .vp9
        case 2: videoCodec = .vp8
        case 3: videoCodec = .h264
        default: fatalError()
        }
        
        // 入力された設定を元にSoraへ接続を行います。
        // この画面からは配信側に接続を行うため、role引数には .publisher を指定しています。
        // また今回のサンプルアプリでは、デフォルトのカメラ映像のキャプチャではなく、加工されたカメラ映像のキャプチャを使用したいため、
        // videoCapturerOptionをカスタムに設定しておきます。
        SoraSDKManager.shared.connect(
            channelId: channelId,
            role: .publisher,
            videoCodec: videoCodec,
            videoCapturerOption: .custom
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
    @IBAction func onUnwindToPublisherConfig(_ segue: UIStoryboardSegue) {
        // 前の画面から戻ってきても、特に処理は何も行いません。
    }
    
}
