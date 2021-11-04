import UIKit
import Sora

/**
 ビデオチャットを行う画面です。
 */
class VideoChatRoomViewController: UIViewController {
    
    /** ビデオチャットの、配信者以外の参加者の映像を表示するためのViewです。 */
    private var downstreamVideoViews: [VideoView] = []
    
    /** ビデオチャットの、配信者自身の映像を表示するためのViewです。 */
    private var upstreamVideoView: VideoView?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // チャット画面に遷移する直前に、タイトルを現在のチャンネルIDを使用して書き換えています。
        if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
            navigationItem.title = "チャット中: \(mediaChannel.configuration.channelId)"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // このビデオチャットではチャット中に別のクライアントが入室したり退室したりする可能性があります。
        // 入室退室が発生したら都度動画の表示を更新しなければなりませんので、そのためのコールバックを設定します。
        if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
            mediaChannel.handlers.onAddStream = { [weak self] _ in
                NSLog("mediaChannel.handlers.onAddStream")
                DispatchQueue.main.async {
                    self?.handleUpdateStreams()
                }
            }
            mediaChannel.handlers.onRemoveStream = { [weak self] _ in
                NSLog("mediaChannel.handlers.onRemoveStream")
                DispatchQueue.main.async {
                    self?.handleUpdateStreams()
                }
            }
        }
        
        // その後、動画の表示を初回更新します。次回以降の更新は直前に設定したコールバックが行います。
        handleUpdateStreams()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // viewDidAppearで設定したコールバックを、対になるここで削除します。
        if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
            mediaChannel.handlers.onAddStream = nil
            mediaChannel.handlers.onRemoveStream = nil
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // 画面のサイズクラスが変更になるとき（画面回転などが対象です）、
        // 再レイアウトが必要になるので、アニメーションに合わせて画面の再レイアウトを粉います。
        coordinator.animate(alongsideTransition: { [weak self] context in
            self?.layoutVideoViews(for: size)
        })
    }
    
    fileprivate func layoutVideoViews(for size: CGSize) {
        // 画面が縦方向に長いか横方向に長いかによってレイアウトを分けることにしたいので、最初に判定します。
        let isPortrait = size.height > size.width
        
        // 同室の他のユーザーの配信のVideoViewをレイアウトします。
        // このレイアウトは現在同室に入っているユーザーの数に応じて変化します。
        // ここでは最大で12ユーザーまでをサポートすることにします。
        let videoViews = downstreamVideoViews.prefix(12)
        switch videoViews.count {
        case 1:
            // 1ユーザの場合は画面全体に表示します。
            let videoView = videoViews[0]
            videoView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        case 2:
            // 2ユーザの場合は二分割します。
            let videoView0 = videoViews[0]
            let videoView1 = videoViews[1]
            if isPortrait {
                videoView0.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height/2)
                videoView1.frame = CGRect(x: 0, y: size.height/2, width: size.width, height: size.height/2)
            } else {
                videoView0.frame = CGRect(x: 0, y: 0, width: size.width/2, height: size.height)
                videoView1.frame = CGRect(x: size.width/2, y: 0, width: size.width/2, height: size.height)
            }
        case 3 ... 4:
            // 3~4ユーザーの場合は四等分します。
            let videoView0 = videoViews[0]
            let videoView1 = videoViews[1]
            let videoView2 = videoViews[2]
            videoView0.frame = CGRect(x: 0, y: 0, width: size.width/2, height: size.height/2)
            videoView1.frame = CGRect(x: size.width/2, y: 0, width: size.width/2, height: size.height/2)
            videoView2.frame = CGRect(x: 0, y: size.height/2, width: size.width/2, height: size.height/2)
            if videoViews.count == 4 {
                let videoView3 = videoViews[3]
                videoView3.frame = CGRect(x: size.width/2, y: size.height/2, width: size.width/2, height: size.height/2)
            }
        case 5 ... 12:
            // それ以上の場合には、長辺を４等分、短辺を２〜３等分して、左上から順番に、最大８〜１２個を並べるようにします。
            // 最初にX方向の分割数mxとY方向の分割数myを計算します。
            // 条件として、(縦向きか否か && videoViewの枚数は８枚以下かそれ以上か)によって分岐させます。
            let mx: Int
            let my: Int
            switch (isPortrait, videoViews.count > 8) {
            case (true, true): (mx, my) = (3, 4)   // 縦向き、最大１２枚
            case (true, false): (mx, my) = (2, 4)  // 縦向き、８枚まで
            case (false, true): (mx, my) = (4, 3)  // 横向き、最大１２枚
            case (false, false): (mx, my) = (4, 2) // 横向き、８枚まで
            }
            // あとはループを回して１枚ずつ左上から右下方向にvideoViewsをタイル状に並べていくだけです。
            // このときタイル(x, y)は、videoViews[y * my + x]番目に相当します。
            // そこで(y * my + x)がvideoViewsの実際の枚数を超えない間だけループを回すようにしています。
            for y in 0 ..< my {
                for x in 0 ..< mx where (y * my + x) < videoViews.count {
                    let videoView = videoViews[y * my + x]
                    let width = size.width / CGFloat(mx)
                    let height = size.height / CGFloat(my)
                    videoView.frame = CGRect(x: CGFloat(x) * width,
                                             y: CGFloat(y) * height,
                                             width: width,
                                             height: height)
                }
            }
        default:
            // このケースは存在しえません。
            break
        }
        
        // 自分自身の配信を写すためのVideoViewを設定します。
        // このVideoViewは最前面にフロートして表示されるようになります。
        if let videoView = upstreamVideoView {
            let floatingSize = CGSize(width: 100, height: 150)
            videoView.frame = CGRect(x: size.width - floatingSize.width - 20.0,
                                     y: size.height - floatingSize.height - 20.0,
                                     width: floatingSize.width,
                                     height: floatingSize.height)
            view.bringSubviewToFront(videoView)
        }
    }
    
}

// MARK: - Sora SDKのイベントハンドリング

extension VideoChatRoomViewController {
    
    /**
     接続されている配信者の数が変化したときに呼び出されるべき処理をまとめています。
     */
    private func handleUpdateStreams() {
        
        // まずはmediaPublisherのmediaStreamを取得します。
        guard (SoraSDKManager.shared.currentMediaChannel?.streams) != nil else {
            return
        }
        
        // mediaStreamを端末とそれ以外のユーザーのリストに分けます。
        // CameraVideoCapturer が管理するストリームと同一の ID であれば端末の配信ストリームです。
        let upstream = SoraSDKManager.shared.currentMediaChannel?.senderStream
        let downstreams = SoraSDKManager.shared.currentMediaChannel?.receiverStreams ?? []

        // 同室の他のユーザーの配信を見るためのVideoViewを設定します。
        if downstreamVideoViews.count < downstreams.count {
            // 用意されているVideoViewの数が足りないので、新たに追加します。
            // このとき、VideoView.contentModeを変化させることで、描画モードを調整することができます。
            // 今回は枠に合わせてアスペクト比を保ったまま領域全体を埋めたいので、.scaleAspectFillを指定しています。
            for _ in downstreams[downstreamVideoViews.count ..< downstreams.count] {
                let videoView = VideoView()
                videoView.contentMode = .scaleAspectFill
                view.addSubview(videoView)
                downstreamVideoViews.append(videoView)
            }
        } else if downstreamVideoViews.count > downstreams.count {
            // 人が抜けたためにVideoViewが余っているので、削除します。
            for videoView in downstreamVideoViews[downstreams.count ..< downstreamVideoViews.count] {
                videoView.removeFromSuperview()
            }
            downstreamVideoViews.removeSubrange(downstreams.count ..< downstreamVideoViews.count)
        } else {
            // 既に全員分のVideoViewの準備が出来ているので、VideoViewの追加削除は必要ありません。
        }
        for (downstream, videoView) in zip(downstreams, downstreamVideoViews) {
            downstream.videoRenderer = videoView
        }
        
        // 自分自身の配信を写すためのVideoViewを設定します。
        // このとき、VideoView.contentModeを変化させることで、描画モードを調整することができます。
        // 今回は枠に合わせてアスペクト比を保ったまま領域全体を埋めたいので、.scaleAspectFillを指定しています。
        if upstreamVideoView == nil {
            let videoView = VideoView(frame: .zero)
            videoView.contentMode = .scaleAspectFill
            videoView.layer.borderColor = UIColor.white.cgColor
            videoView.layer.borderWidth = 1.0
            view.addSubview(videoView)
            upstreamVideoView = videoView
        }
        upstream?.videoRenderer = upstreamVideoView
        
        // 最後に今セットアップしたVideoViewを正しく画面上でレイアウトします。
        self.layoutVideoViews(for: self.view.bounds.size)
    }
    
    /**
     接続が切断されたときに呼び出されるべき処理をまとめています。
     この切断は、能動的にこちらから切断した場合も、受動的に何らかのエラーなどが原因で切断されてしまった場合も、
     いずれの場合も含めます。
     */
    private func handleDisconnect() {
        // 明示的に配信をストップしてから、画面を閉じるようにしています。
        SoraSDKManager.shared.disconnect()
        // ExitセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
        performSegue(withIdentifier: "Exit", sender: self)
    }
    
}

// MARK: - Interface Builderのための実装

extension VideoChatRoomViewController {
    
    /**
     カメラボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onCameraButton(_ sender: UIBarButtonItem) {
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
        handleDisconnect()
    }
    
}
