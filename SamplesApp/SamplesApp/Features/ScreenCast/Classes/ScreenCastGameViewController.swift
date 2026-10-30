import Sora
import UIKit

private let logger = SamplesLogger.tagged("ScreenCastGame")

/// 0.0~1.0の間の乱数を生成する関数です。
private func randomCGFloat() -> CGFloat {
  CGFloat.random(in: 0...1)
}

// MARK: -

/// 配信されるゲーム画面です。
class ScreenCastGameViewController: UIViewController {
  private enum BoundaryIdentifier {
    static let floor = "Floor"
    static let void = "Void"
  }

  private static let boxSize: CGFloat = 64
  private static let platformHeightRatio: CGFloat = 0.5

  /// 配信開始ボタンです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet private var cameraButton: UIBarButtonItem!
  /// 配信停止ボタンです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
  @IBOutlet private var pauseButton: UIBarButtonItem!

  /// サンプルゲーム自体の実装のために使用します。UI Dynamicsという仕組みを使用しています。
  private var animator: UIDynamicAnimator!
  /// サンプルゲーム自体の実装のために使用します。UI Dynamicsという仕組みを使用しています。
  private var gravity: UIGravityBehavior!
  /// サンプルゲーム自体の実装のために使用します。UI Dynamicsという仕組みを使用しています。
  private var collision: UICollisionBehavior!
  /// サンプルゲーム自体の実装のために使用します。UI Dynamicsという仕組みを使用しています。
  private var dynamicProperties: UIDynamicItemBehavior!

  private let platformView = UIView()
  private var gameAreaFrame: CGRect = .zero
  private var floorY: CGFloat = 0
  private var cameraThumbnailView: VideoView?
  private var isDisconnecting = false
  // 画面キャプチャとカメラのイベント購読タスクです。接続ごとに作り直します。
  private var screenEventTask: Task<Void, Never>?
  private var cameraEventTask: Task<Void, Never>?

  override func viewDidLoad() {
    super.viewDidLoad()

    // UI Dynamicsのための設定を行います。
    animator = UIDynamicAnimator(referenceView: view)

    gravity = UIGravityBehavior(items: [])

    collision = UICollisionBehavior(items: [])
    collision.collisionDelegate = self

    dynamicProperties = UIDynamicItemBehavior(items: [])
    dynamicProperties.density = 1.0
    dynamicProperties.elasticity = 0.5
    dynamicProperties.friction = 0.1

    animator.addBehavior(gravity)
    animator.addBehavior(collision)
    animator.addBehavior(dynamicProperties)

    platformView.backgroundColor = .black
    platformView.isUserInteractionEnabled = false
    view.addSubview(platformView)

    // 画面タッチ時のアクションを定義します。
    let tapGR = UITapGestureRecognizer(target: self, action: #selector(onViewTapped(_:)))
    view.addGestureRecognizer(tapGR)

    // ナビゲーションバーのボタンの状態を更新します。
    updateBarButtonItems()

  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateGameAreaBoundariesIfNeeded()
    layoutCameraThumbnail()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // メインメニューに戻るときなどに配信が継続しないように、接続中または接続試行中の
    // 場合は切断します。配信設定画面を開くときはまだ接続していないため、
    // 設定画面を表示してもここで切断されることはありません。
    guard ScreenCastConnectionManager.shared.isActive else {
      return
    }
    guard beginDisconnectIfNeeded() else {
      return
    }

    // 閉じた画面は解放されるため、切断を非同期処理に預けず、ここで完了させます。
    // 画面録画の停止は MediaChannel の切断処理でも行われるため、ここでは待ちません。
    disconnectSession()
  }

  // MARK: - Action

  /// 画面タッチ時のアクションを定義します。
  @objc
  func onViewTapped(_ gestureRecognizer: UITapGestureRecognizer) {
    // タッチした場所に新しい箱を発生させます。
    let location = gestureRecognizer.location(in: view)
    addBox(at: location)
  }

  /// 配信開始ボタンが押されたときの挙動を定義します。
  @IBAction
  func onCameraButton(_ sender: UIBarButtonItem) {
    let isConnected = ScreenCastConnectionManager.shared.isActive
    if isConnected {
      // 既に配信中なので何もしなくて良いです。ボタンの状態だけ更新します。
      updateBarButtonItems()
    } else {
      // 配信を開始するため配信設定画面に遷移し、ボタンの状態を更新します。
      performSegue(withIdentifier: "Publish", sender: self)
      updateBarButtonItems()
    }
  }

  /// 配信停止ボタンが押されたときの挙動を定義します。
  @IBAction
  func onPauseButton(_ sender: UIBarButtonItem) {
    let isConnected = ScreenCastConnectionManager.shared.isActive
    if isConnected {
      handleDisconnect()
    } else {
      // 配信されていないので何もしなくて良いです。ボタンの状態だけ更新します。
      updateBarButtonItems()
    }
  }

  /// 配信設定画面からのUnwind Segueの着地地点として定義してあります。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction
  func onUnwindByConnect(_ segue: UIStoryboardSegue) {
    // 接続が完了して配信設定画面から戻ってきたので、画面録画を開始して配信をスタートします。
    // 画面録画の開始 / 停止は Sora iOS SDK の API を利用します。
    //
    // SDK は `RPSampleBufferType.video` のみ送信します。
    // ReplayKit のマイク / カメラ入力は利用できません。
    startMediaChannelEventSubscriptions()
    setupCameraThumbnail()
    updateBarButtonItems()

    // 画面録画の開始は非同期で行います。
    Task { [weak self] in
      await self?.startScreenCapture()
    }
  }

  /// 画面録画を開始します。
  ///
  /// `startScreenCapture` は SDK が nonisolated な非同期メソッドとして宣言しているため、
  /// 呼び出し元の actor では実行されない (コンパイラの診断では @concurrent と表示される)。
  /// `@MainActor` の文脈から MainActor 領域の MediaChannel と ScreenCaptureSettings をそのまま
  /// 渡すと `sending ... risks causing data races` になるため、nonisolated(unsafe) にして
  /// 隔離を外す (SDK のドキュメントのパターン)。
  private func startScreenCapture() async {
    guard let channel = ScreenCastConnectionManager.shared.screenMediaChannel else {
      return
    }
    nonisolated(unsafe) let mediaChannel = channel
    nonisolated(unsafe) let captureSettings = ScreenCaptureSettings(
      targetFPS: ScreenCastEnvironment.screenCaptureTargetFPS,
      onRuntimeError: { @Sendable [weak self] error in
        // このクロージャーはデフォルトのアクター隔離 (MainActor) を継承してしまうため、
        // @Sendable にしてアクター隔離を外す。
        // (@Sendable にしないと、ReplayKit の startCapture ハンドラから呼び出された瞬間に
        // Swift 6 の実行時隔離チェックが trap して EXC_BREAKPOINT になる)
        Task { @MainActor in
          logger.warning(
            "[sample] Error while mediaChannel.startScreenCapture(runtime): \(error)"
          )
          self?.handleDisconnect()
        }
      }
    )

    do {
      try await mediaChannel.startScreenCapture(settings: captureSettings)
    } catch {
      // エラーが発生して画面録画が開始できなかった場合は、Soraへの配信を停止する必要があります。
      // 例えばユーザーが画面録画を許可しなかった場合などもこのエラーが発生します。
      logger.warning("[sample] Error while mediaChannel.startScreenCapture: \(error)")
      handleDisconnect()
    }
  }

  /// 接続が切断されたときに呼び出されるべき処理をまとめています。
  /// この切断は、能動的にこちらから切断した場合も、受動的に何らかのエラーなどが原因で切断されてしまった場合も、
  /// いずれの場合も含めます。
  private func handleDisconnect() {
    Task { [weak self] in
      guard let self = self else { return }
      guard self.beginDisconnectIfNeeded() else { return }

      // 画面録画を停止します。切断時にもSDK側で停止されますが、明示的に停止しておきます。
      await self.stopScreenCapture()
      self.disconnectSession()
    }
  }

  /// 明示的に配信をストップし、切断後の状態にします。
  private func disconnectSession() {
    teardownCameraThumbnail()
    ScreenCastConnectionManager.shared.disconnect()
    isDisconnecting = false
    updateBarButtonItems()
  }

  /// 画面録画を停止します。
  ///
  /// `stopScreenCapture` も nonisolated な非同期メソッドのため、`startScreenCapture` と同じ理由で
  /// nonisolated(unsafe) にして隔離を外します。
  private func stopScreenCapture() async {
    guard let channel = ScreenCastConnectionManager.shared.screenMediaChannel else {
      return
    }
    nonisolated(unsafe) let mediaChannel = channel
    await mediaChannel.stopScreenCapture()
  }

  /// 配信設定画面からのUnwind Segueの着地地点として定義してあります。
  /// 詳細はMain.storyboardの設定をご確認ください。
  @IBAction
  func onUnwindByExit(_ segue: UIStoryboardSegue) {
    // 単純に閉じるボタンで配信設定画面を閉じただけなので、特に処理は何も行いません。
  }

  // MARK: - Private

  /// ゲーム用の実装です。指定された地点に箱を追加します。
  private func addBox(at point: CGPoint) {
    let gameArea = gameAreaFrame == .zero ? currentGameAreaFrame() : gameAreaFrame
    let platformHeight = Self.boxSize * Self.platformHeightRatio
    let currentFloorY = floorY == 0 ? gameArea.maxY - platformHeight : floorY
    let halfSize = Self.boxSize / 2
    let clampedCenterX = min(max(point.x, gameArea.minX + halfSize), gameArea.maxX - halfSize)
    let clampedCenterY = min(
      max(point.y, gameArea.minY + halfSize),
      currentFloorY - halfSize
    )
    let box = UIView(
      frame: CGRect(
        x: clampedCenterX - halfSize,
        y: clampedCenterY - halfSize,
        width: Self.boxSize,
        height: Self.boxSize
      ))
    box.backgroundColor = UIColor(
      hue: randomCGFloat(), saturation: randomCGFloat(), brightness: randomCGFloat(),
      alpha: 1.0)
    view.addSubview(box)
    if let cameraThumbnailView {
      view.bringSubviewToFront(cameraThumbnailView)
    }
    gravity.addItem(box)
    collision.addItem(box)
    dynamicProperties.addItem(box)
  }

  /// ゲーム用の実装です。箱を削除します。
  private func removeBox(_ box: UIView) {
    box.removeFromSuperview()
    gravity.removeItem(box)
    collision.removeItem(box)
    dynamicProperties.removeItem(box)
  }

  /// 現在の配信状態に応じてナビゲーションバーのボタンの状態を更新します。
  private func updateBarButtonItems() {
    let isConnected = ScreenCastConnectionManager.shared.isActive
    if isConnected {
      navigationItem.rightBarButtonItems = [pauseButton]
    } else {
      navigationItem.rightBarButtonItems = [cameraButton]
    }
  }

  private func currentGameAreaFrame() -> CGRect {
    let safeFrame = view.safeAreaLayoutGuide.layoutFrame
    if safeFrame.isEmpty {
      return view.bounds
    }
    return safeFrame
  }

  private func updateGameAreaBoundariesIfNeeded() {
    let newFrame = currentGameAreaFrame()
    guard !newFrame.isEmpty else {
      return
    }
    guard newFrame != gameAreaFrame else {
      return
    }

    gameAreaFrame = newFrame
    collision.removeAllBoundaries()

    // 土台は左右にブロック1個分の余白を設けます。
    let floorStartX = newFrame.minX + Self.boxSize
    let floorEndX = newFrame.maxX - Self.boxSize
    let floorMinX = min(floorStartX, floorEndX)
    let floorMaxX = max(floorStartX, floorEndX)
    let platformHeight = Self.boxSize * Self.platformHeightRatio
    floorY = newFrame.maxY - platformHeight

    platformView.frame = CGRect(
      x: floorMinX,
      y: floorY,
      width: floorMaxX - floorMinX,
      height: platformHeight
    )

    collision.addBoundary(
      withIdentifier: BoundaryIdentifier.floor as NSString,
      from: CGPoint(x: floorMinX, y: floorY),
      to: CGPoint(x: floorMaxX, y: floorY))

    // 浮動小数誤差などで床をすり抜けた個体を破棄する保険境界です。
    collision.addBoundary(
      withIdentifier: BoundaryIdentifier.void as NSString,
      from: CGPoint(x: newFrame.minX - 1000, y: newFrame.maxY + 10),
      to: CGPoint(x: newFrame.maxX + 1000, y: newFrame.maxY + 10))
  }

  private func startMediaChannelEventSubscriptions() {
    // 画面キャプチャとカメラの切断、カメラのストリームの追加と削除は購読 API で受けます。
    // 購読を開始してから Task で受信します (購読を開始する前に配送されたイベントは届きません)。
    if let screenMediaChannel = ScreenCastConnectionManager.shared.screenMediaChannel {
      let events = screenMediaChannel.subscribeEvents()
      screenEventTask?.cancel()
      screenEventTask = Task { [weak self] in
        for await event in events {
          guard let self else { return }
          switch event.kind {
          case .disconnected:
            logMediaChannelDisconnected(
              event,
              logger: logger,
              label: ScreenCastConnectionManager.shared.logLabel(for: .screen)
            )
            self.handleDisconnect()
          default:
            break
          }
        }
      }
    }

    if let cameraMediaChannel = ScreenCastConnectionManager.shared.cameraMediaChannel {
      let events = cameraMediaChannel.subscribeEvents()
      cameraEventTask?.cancel()
      cameraEventTask = Task { [weak self] in
        for await event in events {
          guard let self else { return }
          switch event.kind {
          case .disconnected:
            logMediaChannelDisconnected(
              event,
              logger: logger,
              label: ScreenCastConnectionManager.shared.logLabel(for: .camera)
            )
            self.handleDisconnect()
          case .streamAdded:
            self.setupCameraThumbnail()
          case .streamRemoved:
            self.teardownCameraThumbnail()
          default:
            break
          }
        }
      }
    }
  }

  private func setupCameraThumbnail() {
    guard
      let cameraMediaChannel = ScreenCastConnectionManager.shared.cameraMediaChannel,
      let senderStream = cameraMediaChannel.senderStream
    else {
      teardownCameraThumbnail()
      return
    }

    let thumbnailView: VideoView
    if let cameraThumbnailView {
      thumbnailView = cameraThumbnailView
    } else {
      let videoView = VideoView(frame: .zero)
      videoView.contentMode = .scaleAspectFill
      videoView.layer.borderColor = UIColor.white.cgColor
      videoView.layer.borderWidth = 1.0
      videoView.layer.cornerRadius = 8.0
      videoView.clipsToBounds = true
      videoView.connectionMode = .manual
      videoView.start()
      view.addSubview(videoView)
      cameraThumbnailView = videoView
      thumbnailView = videoView
    }

    senderStream.videoRenderer = thumbnailView
    layoutCameraThumbnail()
    view.bringSubviewToFront(thumbnailView)
  }

  private func layoutCameraThumbnail() {
    guard let cameraThumbnailView else { return }
    let margin: CGFloat = 12
    let width = min(120, max(96, view.bounds.width * 0.28))
    let height = width * 1.5
    let x = view.bounds.width - view.safeAreaInsets.right - width - margin
    let y = view.safeAreaInsets.top + margin
    cameraThumbnailView.frame = CGRect(x: x, y: y, width: width, height: height)
  }

  private func teardownCameraThumbnail() {
    if let senderStream = ScreenCastConnectionManager.shared.cameraMediaChannel?.senderStream {
      senderStream.videoRenderer = nil
    }
    cameraThumbnailView?.removeFromSuperview()
    cameraThumbnailView = nil
  }

  /// 切断処理を開始してよいかを返します。
  ///
  /// 重複して切断処理が呼ばれないように、開始できる場合だけイベントの購読を終了します。
  private func beginDisconnectIfNeeded() -> Bool {
    if isDisconnecting {
      return false
    }
    isDisconnecting = true
    screenEventTask?.cancel()
    screenEventTask = nil
    cameraEventTask?.cancel()
    cameraEventTask = nil
    return true
  }
}

// MARK: - UICollisionBehaviorDelegate

extension ScreenCastGameViewController: UICollisionBehaviorDelegate {
  /// ゲーム用の実装です。箱がバウンダリに接触したときの挙動を定義します。
  /// ここでは画面外バウンダリに箱が接触したときに箱を削除しています。
  func collisionBehavior(
    _ behavior: UICollisionBehavior, beganContactFor item: UIDynamicItem,
    withBoundaryIdentifier identifier: NSCopying?, at contactPoint: CGPoint
  ) {
    guard let boundaryName = identifier as? String else {
      fatalError()
    }
    switch boundaryName {
    case BoundaryIdentifier.void:
      if let box = item as? UIView {
        removeBox(box)
      }
    default:
      break
    }
  }
}
