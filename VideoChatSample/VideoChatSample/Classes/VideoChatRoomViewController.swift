import Sora
import UIKit
import AVFoundation

/// ビデオチャットを行う画面です。
class VideoChatRoomViewController: UIViewController {
  /// ビデオチャットの、配信者以外の参加者の映像を表示するためのViewです。
  private var downstreamVideoViews: [VideoView] = []

  /// ビデオチャットの、配信者自身の映像を表示するためのViewです。
  private var upstreamVideoView: VideoView?
    private let captureSessionQueue = DispatchQueue(
        label: "captureSessionQueue", qos: .userInitiated, attributes: DispatchQueue.Attributes())
    private let captureSession = AVCaptureSession()
    private var authorizationStatus: AVAuthorizationStatus?
    private var configurationFinished: Bool = false
    private var captureDevicePosition: AVCaptureDevice.Position = .front
    private var currentFilter: CIFilter?

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // チャット画面に遷移する直前に、タイトルを現在のチャンネルIDを使用して書き換えています。
    if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
      navigationItem.title = "チャット中: \(mediaChannel.configuration.channelId)"
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
      if authorizationStatus == nil {
          // 映像キャプチャデバイス（要するにカメラ）を使用するには、最初にユーザーからの明示的な許可を得る必要があります。
          // ここでは許可状況を確認し、それに応じて処理を分岐しています。
          switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
          case .authorized:
              // 既に許可が得られているので、そのまま続行します。
              authorizationStatus = .authorized
          case .notDetermined:
              // まだ一度もユーザーに対して許可を得るダイアログを表示していないため、ここで許可を得るためのダイアログを表示します。
              // ユーザーがダイアログに対して返事を返すまでの間、captureSessionQueueを停止させ、処理をサスペンドしています。
              // ユーザーがダイアログに対して処理を返してきたら、そのステータスに応じて処理を続行するため、captureSessionQueueを再開させます。
              captureSessionQueue.suspend()
              AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] granted in
                  if !granted {
                      self?.authorizationStatus = .denied
                  } else {
                      self?.authorizationStatus = .authorized
                  }
                  self?.captureSessionQueue.resume()
              }
          default:
              // 既に明示的に拒否されているため、そのまま続行します。
              authorizationStatus = .denied
          }
      }
      
      // captureSessionをセットアップしたのち、映像キャプチャを開始します。
      // これはcaptureSessionQueue内で実行されるため、captureSessionQueueが停止されている間は処理が先に進みません。
      // これによって、ユーザーから許可を得るまでの間、処理を効果的に一時停止することができます。
      captureSessionQueue.async { [weak self] in
          if let finished = self?.configurationFinished, !finished {
              self?.configureCaptureSession()
          }
          self?.captureSession.startRunning()
      }

    // このビデオチャットではチャット中に別のクライアントが入室したり退室したりする可能性があります。
    // 入室退室が発生したら都度動画の表示を更新しなければなりませんので、そのためのコールバックを設定します。
    if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
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
      mediaChannel.handlers.onDisconnect = { [weak self] _ in
        NSLog("[sample] mediaChannel.handlers.onDisconnect")
        DispatchQueue.main.async {
          self?.handleDisconnect()
        }
      }
        
        mediaChannel.handlers.onDataChannelMessage = { [weak self] _, label, data in
            guard let self, label.starts(with: "#") else {
                return
            }
            
            switch label {
            case Environment.dataChanelLabel:
                if let message = String(data: data, encoding: .utf8) {
                    print("hieunh: \(message)")
                    handleDisconnect()
                } else {
                    print("message data could not be converted to string")
                }
            default:
                print("not my label")
            }
        }
    }

    // その後、動画の表示を初回更新します。次回以降の更新は直前に設定したコールバックが行います。
    handleUpdateStreams()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
      // captureSessionを停止します。
      captureSessionQueue.async { [weak self] in
          self?.captureSession.stopRunning()
      }

    // viewDidAppearで設定したコールバックを、対になるここで削除します。
    if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
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
      for y in 0..<my {
        for x in 0..<mx where (y * my + x) < videoViews.count {
          let videoView = videoViews[y * my + x]
          let width = size.width / CGFloat(mx)
          let height = size.height / CGFloat(my)
          videoView.frame = CGRect(
            x: CGFloat(x) * width,
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
      videoView.frame = CGRect(
        x: size.width - floatingSize.width - 20.0,
        y: size.height - floatingSize.height - 20.0,
        width: floatingSize.width,
        height: floatingSize.height)
      view.bringSubviewToFront(videoView)
    }
  }
}

// MARK: - Sora SDKのイベントハンドリング

extension VideoChatRoomViewController {
  /// 接続されている配信者の数が変化したときに呼び出されるべき処理をまとめています。
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
      view.addSubview(videoView)
      upstreamVideoView = videoView
    }
    upstream?.videoRenderer = upstreamVideoView

    // 最後に今セットアップしたVideoViewを正しく画面上でレイアウトします。
    layoutVideoViews(for: view.bounds.size)
  }

  /// 接続が切断されたときに呼び出されるべき処理をまとめています。
  /// この切断は、能動的にこちらから切断した場合も、受動的に何らかのエラーなどが原因で切断されてしまった場合も、
  /// いずれの場合も含めます。
  private func handleDisconnect() {
      DispatchQueue.main.async {
          // 明示的に配信をストップしてから、画面を閉じるようにしています。
          SoraSDKManager.shared.disconnect()
          // ExitセグエはMain.storyboard内で定義されているので、そちらをご確認ください。
          self.performSegue(withIdentifier: "Exit", sender: self)
      }
  }
}

// MARK: - Interface Builderのための実装

extension VideoChatRoomViewController {
  /// カメラボタンを押したときの挙動を定義します。
  /// 詳しくはMain.storyboard内の定義をご覧ください。
  @IBAction func onCameraButton(_ sender: UIBarButtonItem) {
    guard let current = CameraVideoCapturer.current else {
      return
    }

    guard current.isRunning else {
      return
    }

    CameraVideoCapturer.flip(current) { error in
      if let error {
        NSLog("[sample] " + error.localizedDescription)
      }
    }
  }

  /// 閉じるボタンを押したときの挙動を定義します。
  /// 詳しくはMain.storyboard内の定義をご覧ください。
  @IBAction func onExitButton(_ sender: UIBarButtonItem) {
      sendMessageToDataChannel(message: "helloworld!")
    handleDisconnect()
  }
}

// MARK: Config Capture Session
extension VideoChatRoomViewController {
    private func configureCaptureSession() {
        // 映像キャプチャデバイスの仕様が許可されている場合のみ続行します。
        // 拒否されている場合は映像キャプチャデバイスを使用できないため、ここで終了します。
        guard authorizationStatus == .authorized else {
            configurationFinished = false
            return
        }
        
        // ここからデバイスのセットアップを行います。
        // 全て終わったら自動的にコミットされます。
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        
        // 入力デバイスのセットアップを行い、captureSessionに設定します。
        guard
            let captureDevice = AVCaptureDevice.default(
                AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video,
                position: captureDevicePosition)
        else {
            configurationFinished = false
            return
        }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            configurationFinished = false
            return
        }
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        if captureSession.canAddInput(captureDeviceInput) {
            captureSession.addInput(captureDeviceInput)
        }
        
        // 出力側のセットアップを行い、captureSessionに設定します。
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: captureSessionQueue)
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        // captureSession経由で、カメラの出力プリセットの設定を行います。
        // デフォルトではカメラの出力できる最も美しい画質で動画を出力するのですが、
        // あまりにも高画質になるとフィルタをかける際に処理コストが高くなりすぎたりするため、
        // ここでは適切な画質に設定しています。
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else {
            captureSession.sessionPreset = .medium
        }
        
        // captureSessionのセットアップが完了したので、最後にこのカメラキャプチャが出力する動画の向きを設定します。
        updateVideoOrientationUsingStatusBarOrientation()
    }
    
    /// 現在のUI上のステータスバーの向きを元に、映像の回転方向を補正します。
    /// こちらのメソッドはデバイスの画面が天頂向き・地面向きの状態であったとしても、ステータスバーの向きを基準に映像を回転させることができますが、
    /// その代わりにデバイス画面が天頂向き・地面向きの状態で使用すると意図しない向きに画面が回ってしまう可能性もあります。
    /// そこで本サンプルでは最初の1回目の補正にのみ使用しています。
    private func updateVideoOrientationUsingStatusBarOrientation() {
        DispatchQueue.main.async {
            let statusBarOrientation = UIApplication.shared.statusBarOrientation
            let videoOrientation =
            AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) ?? .portrait
            for output in self.captureSession.outputs {
                if let connection = output.connection(with: .video) {
                    connection.videoOrientation = videoOrientation
                }
            }
        }
    }
    
    /// 現在のデバイス自体の向きを元に、映像の回転方向を補正します。
    /// こちらのメソッドはデバイスの向きを元に補正するため、デバイス画面が天頂向き・地面向きの状態で使用すると映像を回転させないで終了するようになっています。
    /// （明示的にどちらかの方向にデバイスが傾けられているときにだけ、映像を回転させます）
    /// そこで本サンプルではデバイスが回転したときのイベントに合わせて使用しています。
    private func updateVideoOrientationUsingDeviceOrientation() {
        let deviceOrientation = UIDevice.current.orientation
        guard deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
            return
        }
        guard let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation)
        else {
            return
        }
        for output in captureSession.outputs {
            if let connection = output.connection(with: .video) {
                connection.videoOrientation = videoOrientation
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoChatRoomViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// ビデオキャプチャが、新しいフレームをキャプチャしたときに呼び出されます。
    ///
    /// このサンプルアプリでは、キャプチャされたフレームを適切に変換してSora SDKのmediaStreamに流すことで、配信を行っています。
    /// 注意点として、このdelegate methodはパフォーマンス維持のため、
    /// メインスレッド以外のスレッド (具体的にはcaptureSessionQueue上) にて呼び出されます。
    /// したがってメインスレッド上で直接操作する必要があるコードを呼び出す場合は注意が必要です。
    func captureOutput(
        _ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let mediaChannel = SoraSDKManager.shared.currentMediaChannel,
              let mediaStream = mediaChannel.senderStream
        else {
            return
        }
        if let filter = currentFilter {
            // フィルタが選択されているので、キャプチャした動画にフィルタをかけて配信させます。
            //
            // フィルタの実装方法について:
            // ここでは一番簡単なCore Imageを使ったフィルタリングを実装しています。
            // 大本のビデオフレームバッファ (CMSampleBuffer) から画像フレームバッファ (CVPixelBuffer) を取りだし、
            // Core ImageのCIImageに変換して、フィルタをかけます。
            // 最後にフィルタリングされたCIImageをCIContext経由で元々の画像フレームバッファ領域に上書きレンダリングしています。
            // 元々の画像フレームバッファ領域に直接上書きしているので、大本のビデオフレームバッファをそのまま引き続き使用することができ、
            // 最終的にはこのビデオフレームバッファをSora SDKの提供するVideoFrameに変換して配信することができます。
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
            filter.setValue(cameraImage, forKey: kCIInputImageKey)
            guard let filteredImage = filter.outputImage else {
                return
            }
            let context = CIContext(options: nil)
            context.render(filteredImage, to: pixelBuffer)
            mediaStream.send(videoFrame: VideoFrame(from: sampleBuffer))
        } else {
            // フィルタが選択されていないので、キャプチャした動画をそのまま配信させます。
            mediaStream.send(videoFrame: VideoFrame(from: sampleBuffer))
        }
    }
    
    /// ビデオキャプチャが、何らかの理由でフレーム落ちしたときに呼び出されます。
    func captureOutput(
        _ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // このサンプルアプリでは何もしません。
    }
}

// Data Channel
extension VideoChatRoomViewController {
    private func sendMessageToDataChannel(message: String) {
        guard let mediaChannel = SoraSDKManager.shared.currentMediaChannel else {
            return
        }
        
        // メッセージを送信します。
        if let data: Data = message.data(using: .utf8),
           let error = mediaChannel.sendMessage(label: Environment.dataChanelLabel, data: data) {
            NSLog("cannot send message: \(error)")
            return
        }
    }
}
