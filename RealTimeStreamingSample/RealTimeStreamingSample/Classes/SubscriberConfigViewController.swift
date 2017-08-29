import UIKit

/**
 視聴設定画面です。
 */
class SubscriberConfigViewController: UITableViewController {
    
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
        // スナップショット機能の設定を視聴側（mediaSubscriber）に反映させます。
        // 注意点として、スナップショット機能を使う場合には、以下の２点の設定が必要です。
        // - Video受信を有効にし、コーデックをVP8に指定する
        // - Audio受信を有効にする
        // ただし何もしなければSDK側でこれらのデフォルト設定を満たすようにしてくれるため、ここでは何もしていません。
        SoraSDKManager.shared.connection.mediaSubscriber.mediaOption.snapshotEnabled = snapshotSwitch.isOn
        
        // 視聴側（mediaSubscriber）に接続を行います。
        // 注意点として、mediaSubscriberに対してconnectを呼び出すと、その瞬間にSora SDKは
        // - デバイスのマイク
        // に対するアクセスを要求します。このとき、Info.plist内に
        // - NSMicrophoneUsageDescription
        // の設定がないと、クラッシュしてしまうので、十分にご注意ください。
        // （このサンプルではすでに設定済みです）
        // また設定がされていても、connectを呼び出した瞬間に、ユーザー許可を取るためのダイアログが表示されるので、
        // 突然暗黙的にconnectするのではなく、タップなどのユーザーのアクションに対して明示的にconnectを呼び出すことをおすすめします。
        // 
        // MediaSubscriberは視聴のみを担当するため、デバイスのマイクに対するアクセスを要求するのは違和感が大きいと思いますが、
        // これはWebRTC.frameworkそのものがストリームに接続する際にデバイスのマイクを要求してしまうためであり、現地点では対処法がありません。
        SoraSDKManager.shared.connection.mediaSubscriber.connect { [weak self] error in
            
            if let error = error {
                // errorがnilでないばあいは、接続に失敗しています。
                // この場合は、エラー表示をユーザーに返すのが親切です。
                // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
                // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
                NSLog("mediaSubscriber error: \(error)")
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "接続に失敗しました", message: error.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                }
            } else {
                // errorがnilの場合は、接続に成功しています。
                // 次の視聴画面に遷移します。
                // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
                // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
                NSLog("mediaSubscriber connected.")
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
    @IBAction func onUnwindToSubscriberConfig(_ segue: UIStoryboardSegue) {
        // 前の画面から戻ってきても、特に処理は何も行いません。
    }
    
}
