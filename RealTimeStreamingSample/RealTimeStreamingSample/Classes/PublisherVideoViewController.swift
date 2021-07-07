import UIKit
import Sora

/**
 実際に動画を配信する画面です。
 */
class PublisherVideoViewController: UIViewController {
    
    /// 配信者側の動画を画面に表示するためのビューです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet var videoView: VideoView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // videoViewの表示設定を行います。
        videoView.contentMode = .scaleAspectFill
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 配信画面に遷移する直前に、タイトルを現在のチャンネルIDを使用して書き換えています。
        if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
            navigationItem.title = "配信中: \(mediaChannel.configuration.channelId)"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 配信画面に遷移してきたら、この画面に遷移してきたということはすでに接続が完了しているということなので、
        // videoViewをvideoRendererに設定することで、配信者側の動画を画面に表示させます。
        SoraSDKManager.shared.currentMediaChannel?.senderStream?.videoRenderer = videoView
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 配信画面を何らかの理由で抜けることになったら、videoRendererをnilに戻すことで、videoViewへの動画表示をストップさせます。
        SoraSDKManager.shared.currentMediaChannel?.senderStream?.videoRenderer = nil
    }
    
    /**
     カメラボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onCameraButton(_ sender: UIBarButtonItem) {
        // フロントカメラ・バックカメラを入れ替える処理を行います。
        guard let current = CameraVideoCapturer.current else {
            return
        }
        
        guard current.isRunning else {
            return
        }
        
        CameraVideoCapturer.flip(current) { error in
            if let error = error {
                NSLog(error.localizedDescription)
            }
        }
    }
    
    /**
     閉じるボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onExitButton(_ sender: UIBarButtonItem) {
        // 閉じるボタンを押してもいきなり画面を閉じるのではなく、明示的に配信をストップしてから、画面を閉じるようにしています。
        SoraSDKManager.shared.disconnect()
        // ExitセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
        performSegue(withIdentifier: "Exit", sender: self)
    }
    
}
