import Sora
import UIKit

private let logger = SamplesLogger.tagged("DataChannelVideoChatRoom")

/// ビデオチャットを行う画面です。
class DataChannelVideoChatRoomViewController: UIViewController {
  // 以下のプロパティは UI コンポーネントを保持します。
  // Main.storyboardから設定されていますので、詳細はそちらをご確認ください。

  /// 接続中の URL を表示するコントロールです。
  @IBOutlet weak var connectedUrlLabel: UILabel!

  /// チャットに参加中の映像を表示するコントロールです。
  @IBOutlet weak var memberListView: UIView!

  /// DataChannel ラベルのリストを選択するためのコントロールです。
  @IBOutlet weak var labelPopUpButton: UIButton!

  /// 送信するチャットメッセージを入力するコントロールです。
  @IBOutlet weak var chatMessageToSendTextField: UITextField!

  /// 送受信したチャットメッセージの履歴を表示するコントロールです。
  @IBOutlet weak var historyTableView: UITableView!

  /// タップでメッセージ入力キーボードを閉じるためのジェスチャー認識器です。
  @IBOutlet weak var tapGestureRecognizer: UITapGestureRecognizer!

  /// ビデオチャットの、配信者以外の参加者の映像を表示するためのViewです。
  private var downstreamVideoViews: [VideoView] = []

  // カメラのミュート状態を制御するためのコントローラーです
  private let cameraMuteController = CameraMuteController()

  /// カメラのミュートボタンです。
  @IBOutlet weak var cameraMuteButton: UIBarButtonItem? {
    didSet {
      cameraMuteController.button = cameraMuteButton
    }
  }
  /// 前面/背面カメラ切り替えボタンです。
  @IBOutlet weak var flipCameraButton: UIBarButtonItem? {
    didSet {
      cameraMuteController.flipButton = flipCameraButton
    }
  }

  /// マイクのミュートボタンです。
  @IBOutlet weak var micMuteButton: UIBarButtonItem?

  /// ビデオチャットの、配信者自身の映像を表示するためのViewです。
  private var upstreamVideoView: VideoView?
  // 最後にハンドラ登録した Upstream を覚えておくためのプロパティ
  private weak var observedUpstream: MediaStream?

  // カメラのミュート状態です
  // CameraMuteController 経由で取得します
  private var cameraMuteState: CameraMuteState {
    cameraMuteController.currentState
  }

  // カメラのキャプチャです
  // CameraMuteController 経由で取得します
  private var cameraCapture: CameraVideoCapturer? {
    get { cameraMuteController.cameraCapture }
    set { cameraMuteController.cameraCapture = newValue }
  }

  // カメラのミュートボタンが有効かを返します
  // CameraMuteController 経由で取得します
  private var isCameraMuteButtonAvailable: Bool {
    get { cameraMuteController.isButtonAvailable }
    set { cameraMuteController.isButtonAvailable = newValue }
  }

  // カメラのミュート状態の移行処理が進行中か返します
  // CameraMuteController 経由で取得します
  private var isCameraMuteOperationInProgress: Bool {
    get { cameraMuteController.isOperationInProgress }
    set { cameraMuteController.isOperationInProgress = newValue }
  }

  /// マイクのミュート状態です。
  private var isMicSoftMuted: Bool = false

  /// 接続開始時にカメラを有効にするかどうか。設定画面から渡されます。
  var isStartCameraEnabled: Bool = true

  // 接続開始時のカメラの状態適用を行なったかを管理するフラグ
  private var didApplyInitialCameraState = false

  /// チャットメッセージの履歴です。
  var history: [ChatMessage] = []

  /// 配信画面で選択されたラベルです。このラベルでメッセージを送信します。
  var selectedLabel: String?

  /// 送信するバイナリメッセージです。ランダムなバイナリを送信するように指定した場合に使います。
  var binaryToSend: Data?

  override func viewDidLoad() {
    historyTableView.delegate = self
    historyTableView.dataSource = self
    view.addGestureRecognizer(tapGestureRecognizer)

    // メッセージ入力キーボードの上部に Done ボタンを追加します。
    let textFieldToolBar = UIToolbar()
    textFieldToolBar.sizeToFit()
    let spaceItem = UIBarButtonItem(
      barButtonSystemItem: .flexibleSpace, target: self, action: nil)
    let doneItem = UIBarButtonItem(
      barButtonSystemItem: .done, target: self, action: #selector(onTextFieldDidEnd(_:)))
    textFieldToolBar.items = [spaceItem, doneItem]
    chatMessageToSendTextField.inputAccessoryView = textFieldToolBar

    // メッセージの履歴を初期化します。
    history = []
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // チャット画面に遷移する直前に、タイトルを現在のチャンネルIDを使用して書き換えています。
    if let mediaChannel = DataChannelSoraSDKManager.shared.currentMediaChannel {
      navigationItem.title = mediaChannel.configuration.channelId
      connectedUrlLabel.text = mediaChannel.connectedUrl?.absoluteString

      // 送信可能なラベルのリストを表示します。
      var menuElements: [UIMenuElement] = []
      for label in DataChannelEnvironment.dataChannelLabels {
        let command = UIAction(title: label) { [weak self] _ in
          self?.selectedLabel = label
        }
        menuElements.append(command)
      }
      labelPopUpButton.menu = UIMenu(
        title: "ラベル",
        image: nil,
        identifier: nil,
        options: .displayInline,
        children: menuElements)
      labelPopUpButton.showsMenuAsPrimaryAction = true
      selectedLabel = menuElements[0].title

      // メッセージ受信時の挙動を定義します。
      mediaChannel.handlers.onDataChannelMessage = { [weak self] _, label, data in
        guard let weakSelf = self else {
          return
        }

        // "#" で始まるラベル以外は無視します
        guard label.starts(with: "#") else {
          return
        }

        // 受信したメッセージを履歴に追加して画面を更新します。
        DispatchQueue.main.async {
          weakSelf.history.append(ChatMessage(label: label, data: data))
          weakSelf.updateHistoryTableView()
        }
      }

      // ランダムなバイナリを送信するように指定されていたら
      // テキストフィールドを入力不可にし、バイナリを生成します。
      if DataChannelSoraSDKManager.shared.dataChannelRandomBinary {
        chatMessageToSendTextField.isEnabled = false
        generateRandomBinary()
      } else {
        chatMessageToSendTextField.isEnabled = true
        chatMessageToSendTextField.text = nil
      }

      // サーバーから切断されたときのコールバックを設定します。
      mediaChannel.handlers.onDisconnect = { [weak self] event in
        guard let self = self else { return }
        switch event {
        case .ok(let code, let reason):
          logger.info(
            "[sample] mediaChannel.handlers.onDisconnect: code: \(code), reason: \(reason)")
        case .error(let error):
          logger.error(
            "[sample] mediaChannel.handlers.onDisconnect: error: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
          self.handleDisconnect()
        }
      }
    }
  }

  func generateRandomBinary() {
    var binary: [UInt8] = []
    for _ in 0..<8 {
      binary.append(UInt8.random(in: 0..<UInt8.max))
    }
    binaryToSend = Data(binary)

    let formattedBinary = binary.map(\.description).joined(separator: ", ")
    chatMessageToSendTextField.text = formattedBinary
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // このビデオチャットではチャット中に別のクライアントが入室したり退室したりする可能性があります。
    // 入室退室が発生したら都度動画の表示を更新しなければなりませんので、そのためのコールバックを設定します。
    if let mediaChannel = DataChannelSoraSDKManager.shared.currentMediaChannel {
      mediaChannel.handlers.onAddStream = { [weak self] _ in
        logger.info("mediaChannel.handlers.onAddStream")
        DispatchQueue.main.async {
          self?.handleUpdateStreams()
        }
      }
      mediaChannel.handlers.onRemoveStream = { [weak self] _ in
        logger.info("mediaChannel.handlers.onRemoveStream")
        DispatchQueue.main.async {
          self?.handleUpdateStreams()
        }
      }
    }

    // その後、動画の表示を初回更新します。次回以降の更新は直前に設定したコールバックが行います。
    handleUpdateStreams()

    // メッセージ履歴を更新します。
    historyTableView.reloadData()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // viewDidAppearで設定したコールバックを、対になるここで削除します。
    if let mediaChannel = DataChannelSoraSDKManager.shared.currentMediaChannel {
      mediaChannel.handlers.onAddStream = nil
      mediaChannel.handlers.onRemoveStream = nil
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
      memberListView.bringSubviewToFront(videoView)
    }
  }

  // メッセージ履歴の表示を更新します。
  func updateHistoryTableView() {
    // メッセージ履歴の表示を更新します。
    historyTableView.reloadData()

    // 履歴の量が画面に収まらなければ、最下部 (最新) のメッセージにスクロールします。
    if historyTableView.contentSize.height > historyTableView.frame.size.height {
      // historyTableView.reloadData() の直後は再描画が完了していない可能性があるので、一瞬待ってからスクロールを行います。
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let offset = CGPoint(
          x: 0,
          y: self.historyTableView.contentSize.height
            - self.historyTableView.frame.size.height)
        self.historyTableView.setContentOffset(offset, animated: true)
      }
    }
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

  private func handleUpstreamVideoSwitch(isEnabled: Bool) {
    guard cameraMuteState != .hardMuted else {
      logger.error("[sample] Unexpected onSwitchVideo callback during hardMuted state")
      return
    }
    let nextState: CameraMuteState = isEnabled ? .recording : .softMuted
    cameraMuteController.updateButton(to: nextState)
  }

  // カメラのミュート状態遷移を適用します。
  // recording -> soft_mute -> hard_mute -> recording の順に遷移することを前提とします。
  // stop と restart は CameraVideoCapturer の API を利用するため非同期かつ、エラーハンドリングが必要となります。
  private func applyCameraMuteStateTransition(to nextState: CameraMuteState, upstream: MediaStream)
  {
    let previousState = cameraMuteState

    switch nextState {
    case .recording:
      guard previousState == .hardMuted else {
        cameraMuteController.updateButton(to: nextState)
        upstream.videoEnabled = true
        cameraCapture = nil
        return
      }
      guard let capturer = cameraCapture else {
        logger.warning("[sample] Camera capturer is unavailable for restart.")
        cameraMuteController.updateButton(to: previousState)
        upstream.videoEnabled = false
        return
      }
      isCameraMuteOperationInProgress = true
      capturer.restart { [weak self, weak upstream] error in
        DispatchQueue.main.async {
          guard let self = self, let upstream = upstream else { return }
          self.isCameraMuteOperationInProgress = false
          if let error {
            logger.warning("[sample] Failed to restart camera: \(error.localizedDescription)")
            self.cameraMuteController.restoreState(
              to: previousState,
              upstream: upstream,
              capturer: capturer
            )
          } else {
            self.cameraCapture = nil
            self.cameraMuteController.updateButton(to: .recording)
            upstream.videoEnabled = true
          }
        }
      }
    case .softMuted:
      upstream.videoEnabled = false
      cameraMuteController.updateButton(to: nextState)
    case .hardMuted:
      upstream.videoEnabled = false
      guard let capturer = CameraVideoCapturer.current else {
        cameraMuteController.updateButton(to: nextState)
        return
      }
      cameraCapture = capturer
      isCameraMuteOperationInProgress = true
      capturer.stop { [weak self, weak upstream] error in
        DispatchQueue.main.async {
          guard let self = self, let upstream = upstream else { return }
          self.isCameraMuteOperationInProgress = false
          if let error {
            logger.warning("[sample] Failed to stop camera: \(error.localizedDescription)")
            self.cameraMuteController.restoreState(
              to: previousState,
              upstream: upstream,
              capturer: capturer
            )
          } else {
            self.cameraMuteController.updateButton(to: .hardMuted)
          }
        }
      }
    }
  }
}

// MARK: - Sora SDKのイベントハンドリング

extension DataChannelVideoChatRoomViewController {
  // カメラの初期状態を適用します。
  // 開始時カメラ無効、で接続した際に一度だけカメラハードミュートを有効にします。
  private func applyInitialCameraStateIfNeeded(upstream: MediaStream) {
    guard !didApplyInitialCameraState else {
      return
    }
    didApplyInitialCameraState = true

    guard !isStartCameraEnabled else {
      return
    }

    applyCameraMuteStateTransition(to: .hardMuted, upstream: upstream)
  }

  /// 接続されている配信者の数が変化したときに呼び出されるべき処理をまとめています。
  private func handleUpdateStreams() {
    // まずはmediaPublisherのmediaStreamを取得します。
    guard (DataChannelSoraSDKManager.shared.currentMediaChannel?.streams) != nil else {
      return
    }

    // mediaStreamを端末とそれ以外のユーザーのリストに分けます。
    // CameraVideoCapturer が管理するストリームと同一の ID であれば端末の配信ストリームです。
    let upstream = DataChannelSoraSDKManager.shared.currentMediaChannel?.senderStream
    let downstreams = DataChannelSoraSDKManager.shared.currentMediaChannel?.receiverStreams ?? []

    // 同室の他のユーザーの配信を見るためのVideoViewを設定します。
    if downstreamVideoViews.count < downstreams.count {
      // 用意されているVideoViewの数が足りないので、新たに追加します。
      // このとき、VideoView.contentModeを変化させることで、描画モードを調整することができます。
      // 今回は枠に合わせてアスペクト比を保ったまま領域全体を埋めたいので、.scaleAspectFillを指定しています。
      for _ in downstreams[downstreamVideoViews.count..<downstreams.count] {
        let videoView = VideoView()
        videoView.contentMode = .scaleAspectFill
        memberListView.addSubview(videoView)
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
      memberListView.addSubview(videoView)
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
      applyInitialCameraStateIfNeeded(upstream: upstream)

      let toMuteState: CameraMuteState
      if cameraMuteState == .hardMuted || (!isStartCameraEnabled && didApplyInitialCameraState) {
        toMuteState = .hardMuted
      } else if upstream.videoEnabled {
        toMuteState = .recording
      } else {
        toMuteState = .softMuted
      }
      cameraMuteController.updateButton(to: toMuteState)
      upstream.handlers.onSwitchVideo = { [weak self] isEnabled in
        DispatchQueue.main.async {
          self?.handleUpstreamVideoSwitch(isEnabled: isEnabled)
        }
      }
    } else {
      // アップストリームがない場合、処理は不要だがミュート状態はデフォルトの recording にしておく
      cameraMuteController.updateButton(to: .recording)
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
    layoutVideoViews(for: memberListView.bounds.size)
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
    DataChannelSoraSDKManager.shared.disconnect()
    // ExitセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
    performSegue(withIdentifier: "Exit", sender: self)
  }
}

// MARK: - Interface Builderのための実装

extension DataChannelVideoChatRoomViewController {
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
        logger.error(error.localizedDescription)
      }
    }
  }

  /// カメラミュートボタンを押したときの挙動を定義します。
  @IBAction func onCameraMuteButton(_ sender: UIBarButtonItem) {
    guard let mediaChannel = DataChannelSoraSDKManager.shared.currentMediaChannel,
      let upstream = mediaChannel.senderStream
    else {
      return
    }

    let nextState = cameraMuteState.next()
    applyCameraMuteStateTransition(to: nextState, upstream: upstream)
  }

  /// マイクミュートボタンを押したときの挙動を定義します。
  @IBAction func onMicMuteButton(_ sender: UIBarButtonItem) {
    guard let mediaChannel = DataChannelSoraSDKManager.shared.currentMediaChannel,
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

  /// Clear ボタンを押したときの挙動を定義します。
  /// すべてのメッセージ履歴を削除します。
  @IBAction func onClearButton(_ sender: Any?) {
    history = []
    updateHistoryTableView()
  }

  /// メッセージ送信ボタンが押されたときの挙動を定義します。
  @IBAction func onSendButton(_ sender: Any?) {
    guard let label = selectedLabel else {
      return
    }
    guard let mediaChannel = DataChannelSoraSDKManager.shared.currentMediaChannel else {
      return
    }

    // メッセージを送信します。
    let data: Data
    if DataChannelSoraSDKManager.shared.dataChannelRandomBinary {
      guard let binary = binaryToSend else {
        return
      }
      data = binary
    } else {
      guard let text = chatMessageToSendTextField.text else {
        return
      }
      data = text.data(using: .utf8)!
    }

    if let error = mediaChannel.sendMessage(label: label, data: data) {
      logger.error("cannot send message: \(error)")
      return
    }

    if DataChannelSoraSDKManager.shared.dataChannelRandomBinary {
      generateRandomBinary()
    } else {
      chatMessageToSendTextField.text = nil
    }

    // メッセージ履歴を更新します。
    history.append(.init(label: label, data: data))
    updateHistoryTableView()
  }

  /// 画面のタップ時の挙動を定義します。
  @IBAction func onTapView(_ sender: UITapGestureRecognizer) {
    // キーボードが開いていれば閉じます。
    chatMessageToSendTextField.endEditing(true)
  }

  /// メッセージ入力キーボードのテキスト入力終了時の挙動を定義します。
  @IBAction func onTextFieldDidEnd(_ sender: Any?) {
    // キーボードを閉じます。
    chatMessageToSendTextField.endEditing(true)
  }
}

/// メッセージ履歴を表示するテーブルのデリゲートです。
extension DataChannelVideoChatRoomViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // メッセージ履歴の数だけテーブルの列を表示します。
    history.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // メッセージの詳細を表示するセルを用意します。
    let cell =
      historyTableView.dequeueReusableCell(withIdentifier: "HistoryTableViewCell")
      as? ChatMessageHistoryTableViewCell
    guard let chatCell = cell else {
      return UITableViewCell()
    }
    let message = history[indexPath.row]
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    chatCell.timestampLabel.text = formatter.string(from: message.timestamp)
    chatCell.labelLabel.text = message.label
    chatCell.messageLabel.text = message.message
    return chatCell
  }
}

/// 個々のメッセージの内容を表示するセルです。
/// 詳細は Main.storyboard を参照してください。
class ChatMessageHistoryTableViewCell: UITableViewCell {
  @IBOutlet weak var timestampLabel: UILabel!
  @IBOutlet weak var labelLabel: UILabel!
  @IBOutlet weak var messageLabel: UILabel!
}

/// 送受信するメッセージを表します。
class ChatMessage {
  var label: String
  var timestamp: Date
  var data: Data

  // データを文字列に変換します。
  // UTF-8 文字列に変換できない場合はバイナリの内容を数値で表します。
  var message: String? {
    String(data: data, encoding: .utf8) ?? data.map(\.description).joined(separator: ", ")
  }

  init(label: String, data: Data) {
    self.label = label
    timestamp = Date()
    self.data = data
  }
}
