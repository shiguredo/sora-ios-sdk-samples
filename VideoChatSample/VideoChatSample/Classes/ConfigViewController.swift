import UIKit
import Sora

/**
 チャット接続設定画面です。
 */
class ConfigViewController: UITableViewController {
    
    /// チャンネルIDを入力させる欄です。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var channelIdTextField: UITextField!
    /// スナップショット機能の有効無効設定のスイッチです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var snapshotSwitch: UISwitch!
    
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
        
        // 入力されたチャンネルIDをConnectionに設定します。
        SoraSDKManager.shared.connection.mediaChannelId = channelId
        
        // ビデオチャットアプリでは複数のユーザーが同時に配信を行う必要があるため、
        // Multistream接続オプションを有効にする必要があります。
        // mediaPublisherのMultistream機能を有効にし忘れると、同時に一人しか接続できなくなるため、接続時にエラーになります。
        // またMultistream接続オプションを有効にすると、スナップショット機能を使用することはできなくなります。
        SoraSDKManager.shared.connection.mediaPublisher.multistreamEnabled = true
        
        // ビデオチャットアプリでは複数のユーザーが同時に配信と受信を行うため、
        // 配信はmediaPublisherで、受信はmediaSubscriberで個別に行う必要があるのでは、と思うかもしれませんが、その必要はありません。
        // - mediaPublisherは「配信と受信を同時に行うことができる代わりに、接続数に上限がある」
        // - mediaSubscriberは「受信のみを行うことができる代わりに、接続数に上限がない」
        // と考えることができます。
        // したがってビデオチャットアプリの場合には、mediaPublisherのMultistream機能を有効にした上で、
        // 複数のユーザーから同時にmediaPublisherに接続して配信しつつ、
        // その他のユーザーの配信をmediaPublisher同時に受信することができます。
        SoraSDKManager.shared.connection.mediaPublisher.connect { [weak self] error in
            if let error = error {
                NSLog("mediaPublisher error: \(error)")
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "接続に失敗しました", message: error.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                }
            } else {
                NSLog("mediaPublisher connected.")
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
