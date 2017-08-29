import UIKit
import Sora

/**
 実際に動画を配信する画面です。
 */
class PublisherVideoViewController: UIViewController {
    
    /// 配信者側の動画を画面に表示するためのビューです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var videoView: VideoView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 配信画面に遷移する直前に、配信画面のタイトルを現在のチャンネルIDを使用して書き換えています。
        navigationItem.title = "配信中: \(SoraSDKManager.shared.connection.mediaChannelId)"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 配信画面に遷移してきたら、この画面に遷移してきたということはすでにmediaPublisherに接続が完了しているということなので、
        // videoViewをvideoRendererに設定することで、配信者側の動画を画面に表示させます。
        SoraSDKManager.shared.connection.mediaPublisher.mainMediaStream?.videoRenderer = videoView
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 配信画面を何らかの理由で抜けることになったら、videoRendererをnilに戻すことで、videoViewへの動画表示をストップさせます。
        SoraSDKManager.shared.connection.mediaPublisher.mainMediaStream?.videoRenderer = nil
    }
    
    /**
     カメラボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onCameraButton(_ sender: UIBarButtonItem) {
        // フロントカメラ・バックカメラを入れ替える処理を行います。
        SoraSDKManager.shared.connection.mediaPublisher.flipCameraPosition()
    }
    
    /**
     閉じるボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onExitButton(_ sender: UIBarButtonItem) {
        
        // 閉じるボタンを押してもいきなり画面を閉じるのではなく、明示的に配信をストップしてから、画面を閉じるようにしています。
        SoraSDKManager.shared.connection.mediaPublisher.disconnect { [weak self] error in
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
