import UIKit
import Sora

/**
 実際に動画を視聴する画面です。
 */
class SubscriberVideoViewController: UIViewController {
    
    /// 動画を画面に表示するためのビューです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var videoView: VideoView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 視聴画面に遷移する直前に、タイトルを現在のチャンネルIDを使用して書き換えています。
        navigationItem.title = "視聴中: \(SoraSDKManager.shared.connection.mediaChannelId)"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 視聴画面に遷移してきたら、この画面に遷移してきたということはすでにmediaSubscriberに接続が完了しているということなので、
        // videoViewをvideoRendererに設定することで、動画を画面に表示させます。
        SoraSDKManager.shared.connection.mediaSubscriber.mainMediaStream?.videoRenderer = videoView
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 視聴画面を何らかの理由で抜けることになったら、videoRendererをnilに戻すことで、videoViewへの動画表示をストップさせます。
        SoraSDKManager.shared.connection.mediaSubscriber.mainMediaStream?.videoRenderer = nil
    }
    
    /**
     閉じるボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onExitButton(_ sender: UIBarButtonItem) {
        
        // 閉じるボタンを押してもいきなり画面を閉じるのではなく、明示的に受信をストップしてから、画面を閉じるようにしています。
        SoraSDKManager.shared.connection.mediaSubscriber.disconnect { [weak self] error in
            // 切断処理のコールバックで、前の画面に戻るためのUnwind Segueを呼び出しています。
            // エラーハンドリングはここでは省略しています（接続処理と違い、切断処理に失敗する可能性は小さいため）。
            // なお、このコールバックはメインスレッド以外のスレッドから呼び出される可能性があるので、
            // UI操作を行う際には必ずDispatchQueue.main.asyncを使用してメインスレッドでUI処理を呼び出すようにしてください。
            DispatchQueue.main.async {
                // ExitセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
                self?.performSegue(withIdentifier: "Exit", sender: self)
            }
        }
    }
    
}
