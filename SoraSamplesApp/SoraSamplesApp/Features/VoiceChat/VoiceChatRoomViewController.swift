import Sora
import UIKit

/// ビデオチャットを行う画面です。
class VoiceChatRoomViewController: UIViewController {
  // カメラミュート状態管理のための Enum
  private enum CameraMuteState {
    case recording
    case softMuted
    case hardMuted

    func next() -> CameraMuteState {
      switch self {
      case .recording: return .softMuted
      case .softMuted: return .hardMuted
      case .hardMuted: return .recording
      }
    }

    var symbolName: String {
      switch self {
      case .recording: return "video"
      case .softMuted: return "video.slash"
      case .hardMuted: return "video.slash.fill"
      }
    }

    // カメラミュートボタンのアクセシビリティラベル
    // 推した際の次の状態を返します
    var accessibilityLabel: String {
      switch self {
      case .recording: return "カメラをソフトミュート"
      case .softMuted: return "カメラをハードミュート"
      case .hardMuted: return "カメラを再開"
      }
    }
  }

  /// ビデオチャットの、配信者以外の参加者の映像を表示するためのViewです。
  private var downstreamVideoViews: [VideoView] = []

  /// カメラのミュートボタンです。
  @IBOutlet weak var cameraMuteButton: UIBarButtonItem? {
    didSet { updateCameraMuteButtonEnabledState() }
  }

  /// マイクのミュートボタンです。
  @IBOutlet weak var micMuteButton: UIBarButtonItem?

  // ビデオチャットの、配信者自身の映像を表示するためのViewです。
  private var upstreamVideoView: VideoView?
  // 最後にハンドラ登録した Upstream を覚えておくためのプロパティ
  private weak var observedUpstream: MediaStream?

  // カメラのミュート状態です。
  private var cameraMuteState: CameraMuteState = .recording
  private var cameraCapture: CameraVideoCapturer?
  // カメラミュートボタンが有効かどうか管理するフラグです。
  private var isCameraMuteButtonAvailable: Bool = false {
    didSet { updateCameraMuteButtonEnabledState() }
  }
  // カメラミュート状態が変更処理中かどうか管理するフラグです。
  private var isCameraMuteOperationInProgress: Bool = false {
    didSet { updateCameraMuteButtonEnabledState() }
  }

  /// マイクのミュート状態です。
  private var isMicSoftMuted: Bool = false

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // チャット画面に遷移する直前に、タイトルを現在のチャンネルIDを使用して書き換えています。
    if let mediaChannel = VoiceChatSoraSDKManager.shared.currentMediaChannel {
      navigationItem.title = "チャット中: \(mediaChannel.configuration.channelId)"
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // このビデオチャットではチャット中に別のクライアントが入室したり退室したりする可能性があります。
    // 入室退室が発生したら都度動画の表示を更新しなければなりませんので、そのためのコールバックを設定します。
    if let mediaChannel = VoiceChatSoraSDKManager.shared.currentMediaChannel {
      mediaChannel.handlers.onAddStream = { [weak self] _ in
        NSLog("[sample] mediaChannel.handlers.onAddStream")
        DispatchQueue.main.async {
          self?.handleUpdateStreams()
        }
      }
      mediaChannel.handlers.onRemoveStream = { [weak self] _ in
        NSLog("[sample] mediaChannel.handlers.onRemoveStream")
        DispatchQueue.main.async {
          self?.handleUpdateStreams()
        }
      }

      // サーバーから切断されたときのコールバックを設定します。
      mediaChannel.handlers.onDisconnect = { [weak self] event in
        guard let self = self else { return }
        switch event {
        case .ok(let code, let reason):
          NSLog("[sample] mediaChannel.handlers.onDisconnect: code: \(code), reason: \(reason)")
        case .error(let error):
          NSLog("[sample] mediaChannel.handlers.onDisconnect: error: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
          self.handleDisconnect()
        }
      }
    }

    // その後、動画の表示を初回更新します。次回以降の更新は直前に設定したコールバックが行います。
    handleUpdateStreams()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // viewDidAppearで設定したコールバックを、対になるここで削除します。
    if let mediaChannel = VoiceChatSoraSDKManager.shared.currentMediaChannel {
      mediaChannel.handlers.onAddStream = nil
      mediaChannel.handlers.onRemoveStream = nil
      mediaChannel.handlers.onDisconnect = nil
    }
  }

  override func viewWillTransition(
    to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
  ) {
    // 画面のサイズクラスが変更になるとき（画面回転などが対象です）、
    // 再レイアウトが必要になるので、アニメーションに合わせて画面の再レイアウトを粉います。
    coordinator.animate(alongsideTransition: { [weak self] _ in
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
        videoView0.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height / 2)
        videoView1.frame = CGRect(
          x: 0, y: size.height / 2, width: size.width, height: size.height / 2)
      } else {
        videoView0.frame = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
        videoView1.frame = CGRect(
          x: size.width / 2, y: 0, width: size.width / 2, height: size.height)
      }
    case 3...4:
      // 3~4ユーザーの場合は四等分します。
      let videoView0 = videoViews[0]
      let videoView1 = videoViews[1]
      let videoView2 = videoViews[2]
      videoView0.frame = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2)
      videoView1.frame = CGRect(
        x: size.width / 2, y: 0, width: size.width / 2, height: size.height / 2)
      videoView2.frame = CGRect(
        x: 0, y: size.height / 2, width: size.width / 2, height: size.height / 2)
      if videoViews.count == 4 {
        let videoView3 = videoViews[3]
        videoView3.frame = CGRect(
          x: size.width / 2, y: size.height / 2, width: size.width / 2,
          height: size.height / 2)
      }
    case 5...12:
      // それ以上の場合には、長辺を４等分、短辺を２〜３等分して、左上から順番に、最大８〜１２個を並べるようにします。
      // 最初にX方向の分割数mxとY方向の分割数myを計算します。
      // 条件として、(縦向きか否か && videoViewの枚数は８枚以下かそれ以上か)によって分岐させます。
      let mx: Int
      let my: Int
      switch (isPortrait, videoViews.count > 8) {
      case (true, true): (mx, my) = (3, 4)  // 縦向き、最大１２枚
      case (true, false): (mx, my) = (2, 4)  // 縦向き、８枚まで
      case (false, true): (mx, my) = (4, 3)  // 横向き、最大１２枚
      case (false, false): (mx, my) = (4, 2)  // 横向き、８枚まで
      }
      // あとはループを回して１枚ずつ左上から右下方向にvideoViewsをタイル状に並べていくだけです。
      // このときタイル(x, y)は、videoViews[y * my + x]番目に相当します。
      // そこで(y * my + x)がvideoViewsの実際の枚数を超えない間だけループを回すようにしています。
      for rowIndex in 0..<my {
        for columnIndex in 0..<mx where (rowIndex * my + columnIndex) < videoViews.count {
          let videoView = videoViews[rowIndex * my + columnIndex]
          let width = size.width / CGFloat(mx)
          let height = size.height / CGFloat(my)
          videoView.frame = CGRect(
            x: CGFloat(columnIndex) * width,
            y: CGFloat(rowIndex) * height,
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
      videoView.frame = CGRect(
        x: size.width - floatingSize.width - 20.0,
        y: size.height - floatingSize.height - 20.0,
        width: floatingSize.width,
        height: floatingSize.height)
      view.bringSubviewToFront(videoView)
    }
  }

  // カメラミュートボタンの見た目と状態を更新します。
  // 用意されているシステムアイコンの都合上、video シンボルを使用します
  private func updateCameraMuteButton(state: CameraMuteState) {
    cameraMuteState = state
    let symbolName = state.symbolName
    guard let button = cameraMuteButton else { return }
    let image = UIImage(systemName: symbolName)
    if let image = UIImage(systemName: symbolName) {
      button.image = image
    } else {
      button.image = UIImage(named: symbolName)
    }
    button.accessibilityLabel = state.accessibilityLabel
  }

  // ミュート処理状況からカメラミュートボタンが有効かどうかの状態を更新します。
  private func updateCameraMuteButtonEnabledState() {
    guard let button = cameraMuteButton else { return }
    button.isEnabled = isCameraMuteButtonAvailable && !isCameraMuteOperationInProgress
  }

  /// マイクミュートボタンの見た目と状態を更新します。
  private func updateMicMuteButton(isMuted: Bool) {
    isMicSoftMuted = isMuted
    let symbolName: String = isMuted ? "mic.slash" : "mic"
    guard let button = micMuteButton else { return }
    if let image = UIImage(systemName: symbolName) {
      button.image = image
    } else {
      button.image = UIImage(named: symbolName)
    }
    button.accessibilityLabel = isMuted ? "マイクを再開" : "マイクを停止"
  }
}

// MARK: - Sora SDKのイベントハンドリング

extension VoiceChatRoomViewController {
  /// 接続されている配信者の数が変化したときに呼び出されるべき処理をまとめています。
  private func handleUpdateStreams() {
    // まずはmediaPublisherのmediaStreamを取得します。
    guard (VoiceChatSoraSDKManager.shared.currentMediaChannel?.streams) != nil else {
      return
    }

    // mediaStreamを端末とそれ以外のユーザーのリストに分けます。
    // CameraVideoCapturer が管理するストリームと同一の ID であれば端末の配信ストリームです。
    let upstream = VoiceChatSoraSDKManager.shared.currentMediaChannel?.senderStream
    let downstreams = VoiceChatSoraSDKManager.shared.currentMediaChannel?.receiverStreams ?? []

    // 同室の他のユーザーの配信を見るためのVideoViewを設定します。
    if downstreamVideoViews.count < downstreams.count {
      // 用意されているVideoViewの数が足りないので、新たに追加します。
      // このとき、VideoView.contentModeを変化させることで、描画モードを調整することができます。
      // 今回は枠に合わせてアスペクト比を保ったまま領域全体を埋めたいので、.scaleAspectFillを指定しています。
      for _ in downstreams[downstreamVideoViews.count..<downstreams.count] {
        let videoView = VideoView()
        videoView.contentMode = .scaleAspectFill
        view.addSubview(videoView)
        downstreamVideoViews.append(videoView)
      }
    } else if downstreamVideoViews.count > downstreams.count {
      // 人が抜けたためにVideoViewが余っているので、削除します。
      for videoView in downstreamVideoViews[downstreams.count..<downstreamVideoViews.count] {
        videoView.removeFromSuperview()
      }
      downstreamVideoViews.removeSubrange(downstreams.count..<downstreamVideoViews.count)
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
      videoView.connectionMode = .manual
      videoView.start()
      view.addSubview(videoView)
      upstreamVideoView = videoView
    }
    upstream?.videoRenderer = upstreamVideoView

    // ストリームが入れ替わった際はハンドラを明示的に解除する
    // 通常は起こらないが古いストリームからのコールバックが送られる可能性が0でないため
    if observedUpstream !== upstream {
      observedUpstream?.handlers.onSwitchVideo = nil
      observedUpstream?.handlers.onSwitchAudio = nil
      observedUpstream = upstream
    }

    // カメラミュートの状態に応じてボタン等の UI を更新します。
    isCameraMuteButtonAvailable = upstream != nil
    if let upstream {
      let toMuteState: CameraMuteState
      if cameraMuteState == .hardMuted {
        toMuteState = .hardMuted
      } else if upstream.videoEnabled {
        toMuteState = .recording
      } else {
        toMuteState = .softMuted
      }
      updateCameraMuteButton(state: toMuteState)
      upstream.handlers.onSwitchVideo = { [weak self] isEnabled in
        DispatchQueue.main.async {
          self?.handleUpstreamVideoSwitch(isEnabled: isEnabled)
        }
      }
    } else {
      // アップストリームがない場合、処理は不要だがミュート状態はデフォルトの recording にしておく
      updateCameraMuteButton(state: .recording)
      cameraCapture = nil
      isCameraMuteOperationInProgress = false
    }

    // マイクミュートの状態に応じてボタン等の UI を更新する
    micMuteButton?.isEnabled = upstream != nil
    if let upstream {
      updateMicMuteButton(isMuted: !upstream.audioEnabled)
      upstream.handlers.onSwitchAudio = { [weak self] isEnabled in
        DispatchQueue.main.async {
          self?.updateMicMuteButton(isMuted: !isEnabled)
        }
      }
    } else {
      // アップストリームがない場合、処理は不要だがミュート状態はデフォルトの false にしておく
      updateMicMuteButton(isMuted: false)
    }

    // 最後に今セットアップしたVideoViewを正しく画面上でレイアウトします。
    layoutVideoViews(for: view.bounds.size)
  }

  private func handleUpstreamVideoSwitch(isEnabled: Bool) {
    // ハードミュート中にこのコールバックが来る想定はないが、安全のためログを出して抜ける
    guard cameraMuteState != .hardMuted else {
      NSLog("[sample] Unexpected onSwitchVideo callback during hardMuted state")
      return
    }
    let nextState: CameraMuteState = isEnabled ? .recording : .softMuted
    updateCameraMuteButton(state: nextState)
  }

  // カメラのミュート状態遷移を適用します。
  // recording -> soft_mute -> hard_mute -> recording の順に遷移することを前提とします。
  // stop と restart は CameraVideoCapturer の API を利用するため非同期かつ、エラーハンドリングが必要となります。
  private func applyCameraMuteStateTransition(
    to nextState: CameraMuteState,
    upstream: MediaStream
  ) {
    let previousState = cameraMuteState

    switch nextState {
    case .recording:
      // ハードミュート -> ON
      guard previousState == .hardMuted else {
        updateCameraMuteButton(state: nextState)
        upstream.videoEnabled = true
        cameraCapture = nil
        return
      }
      guard let capturer = cameraCapture else {
        NSLog("[sample] Camera capturer is unavailable for restart.")
        updateCameraMuteButton(state: previousState)
        upstream.videoEnabled = false
        return
      }
      isCameraMuteOperationInProgress = true
      // キャプチャーの再開処理
      capturer.restart { [weak self, weak upstream] error in
        DispatchQueue.main.async {
          guard let self = self, let upstream = upstream else { return }
          self.isCameraMuteOperationInProgress = false
          if let error {
            // 再開失敗
            NSLog("[sample] Failed to restart camera: \(error.localizedDescription)")
            // 状態を直前の状態に戻してリトライできるように参照を保持する
            self.restoreCameraMuteState(
              to: previousState,
              upstream: upstream,
              capturer: capturer
            )
          } else {
            // CameraVideoCapturer.current が再稼働したため、誤使用を防ぐためにも nil に戻す
            self.cameraCapture = nil
            self.updateCameraMuteButton(state: .recording)
            upstream.videoEnabled = true
          }
        }
      }
    case .softMuted:
      // ON -> ソフトミュート
      upstream.videoEnabled = false
      updateCameraMuteButton(state: nextState)
    case .hardMuted:
      // ソフトミュート -> ハードミュート
      // ハードミュートでも失敗時の不意の音声送出を防ぐため videoEnabled=false にします
      upstream.videoEnabled = false
      guard let capturer = CameraVideoCapturer.current else {
        updateCameraMuteButton(state: nextState)
        // 既に停止済み
        return
      }
      cameraCapture = capturer
      isCameraMuteOperationInProgress = true
      // キャプチャー停止処理
      capturer.stop { [weak self, weak upstream] error in
        DispatchQueue.main.async {
          guard let self = self, let upstream = upstream else { return }
          self.isCameraMuteOperationInProgress = false
          if let error {
            // 停止失敗
            NSLog("[sample] Failed to stop camera: \(error.localizedDescription)")
            // 直前の状態に戻します
            self.restoreCameraMuteState(
              to: previousState,
              upstream: upstream,
              capturer: capturer
            )
          } else {
            self.updateCameraMuteButton(state: .hardMuted)
          }
        }
      }
    }
  }

  // カメラミュート状態切り替えエラー時に、直前の状態に復帰させます
  private func restoreCameraMuteState(
    to previousState: CameraMuteState,
    upstream: MediaStream,
    capturer: CameraVideoCapturer?
  ) {
    updateCameraMuteButton(state: previousState)
    switch previousState {
    case .recording:
      upstream.videoEnabled = true
      cameraCapture = nil
    case .softMuted:
      upstream.videoEnabled = false
      cameraCapture = nil
    case .hardMuted:
      upstream.videoEnabled = false
      cameraCapture = capturer
    }
  }

  /// 接続が切断されたときに呼び出されるべき処理をまとめています。
  /// この切断は、能動的にこちらから切断した場合も、受動的に何らかのエラーなどが原因で切断されてしまった場合も、
  /// いずれの場合も含めます。
  private func handleDisconnect() {
    // ハンドラを明示的に解除する
    // 通常は起こらないが古いストリームからのコールバックが送られる可能性が0でないため
    observedUpstream?.handlers.onSwitchVideo = nil
    observedUpstream?.handlers.onSwitchAudio = nil
    observedUpstream = nil
    // カメラミュート関連の処理は中断するようにフラグ等を更新します
    cameraCapture = nil
    isCameraMuteOperationInProgress = false
    // 明示的に配信をストップしてから、画面を閉じるようにしています。
    VoiceChatSoraSDKManager.shared.disconnect()
    // ExitセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
    performSegue(withIdentifier: "Exit", sender: self)
  }
}

// MARK: - Interface Builderのための実装

extension VoiceChatRoomViewController {
  /// 前面/背面カメラ切り替えボタンを押したときの挙動を定義します。
  /// 詳しくはMain.storyboard内の定義をご覧ください。
  @IBAction func onFlipCameraButton(_ sender: UIBarButtonItem) {
    guard let current = CameraVideoCapturer.current else {
      return
    }

    guard current.isRunning else {
      return
    }

    CameraVideoCapturer.flip(current) { error in
      if let error {
        NSLog(error.localizedDescription)
      }
    }
  }

  /// カメラミュートボタンを押したときの挙動を定義します。
  @IBAction func onCameraMuteButton(_ sender: UIBarButtonItem) {
    guard let mediaChannel = VoiceChatSoraSDKManager.shared.currentMediaChannel,
      let upstream = mediaChannel.senderStream
    else {
      return
    }

    let nextState = cameraMuteState.next()
    applyCameraMuteStateTransition(to: nextState, upstream: upstream)
  }

  /// マイクミュートボタンを押したときの挙動を定義します。
  @IBAction func onMicMuteButton(_ sender: UIBarButtonItem) {
    guard let mediaChannel = VoiceChatSoraSDKManager.shared.currentMediaChannel,
      let upstream = mediaChannel.senderStream
    else {
      return
    }

    let nextMuted: Bool = !isMicSoftMuted
    upstream.audioEnabled = !nextMuted
    updateMicMuteButton(isMuted: nextMuted)
  }

  /// 閉じるボタンを押したときの挙動を定義します。
  /// 詳しくはMain.storyboard内の定義をご覧ください。
  @IBAction func onExitButton(_ sender: UIBarButtonItem) {
    handleDisconnect()
  }
}
