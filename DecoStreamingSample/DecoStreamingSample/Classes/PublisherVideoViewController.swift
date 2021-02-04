import UIKit
import AVFoundation
import Sora

/**
 実際に動画を配信する画面です。
 */
class PublisherVideoViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var filterPickerView: UIPickerView!
    
    /// 動画に適応できるフィルタの一覧です。ユーザーが選択できるように、事前に定義してあります。
    private static let allFilters: [(String, CIFilter?)] = {
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        let motionBlurFilter = CIFilter(name: "CIMotionBlur")
        let colorInvertFilter = CIFilter(name: "CIColorInvert")
        let colorMonochromeFilter = CIFilter(name: "CIColorMonochrome")
        let comicFilter = CIFilter(name: "CIComicEffect")
        return [
            ("フィルタなし", nil),
            ("モーションブラー", motionBlurFilter),
            ("色反転", colorInvertFilter),
            ("モノクロ", colorMonochromeFilter),
            ("セピア調", sepiaFilter),
            ("マンガ調", comicFilter)
        ]
    }()
    
    /// 配信者側の動画を画面に表示するためのビューです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet private var videoView: VideoView!
    
    private let captureSessionQueue: DispatchQueue = DispatchQueue(label: "captureSessionQueue", qos: .userInitiated, attributes: DispatchQueue.Attributes())
    private let captureSession: AVCaptureSession = AVCaptureSession()
    private var authorizationStatus: AVAuthorizationStatus?
    private var configurationFinished: Bool = false
    private var captureDevicePosition: AVCaptureDevice.Position = .front
    
    private var currentFilter: CIFilter?
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // videoViewの表示設定を行います。
        videoView.contentMode = .scaleAspectFill
        
        // iPad の場合はフィルタ選択の UI を変更します。
        // UIAlertController の動作が不安定なためです。
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            navigationItem.rightBarButtonItems?.remove(editButton)
            filterPickerView.delegate = self
            filterPickerView.dataSource = self
        default:
            filterPickerView.isHidden = true
            filterPickerView.heightAnchor.constraint(equalToConstant: 0).isActive = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 配信画面に遷移する直前に、配信画面のタイトルを現在のチャンネルIDを使用して書き換えています。
        if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
            navigationItem.title = "配信中: \(mediaChannel.configuration.channelId)"
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
        // 注: iOS14 で以下のコードを実行するとクラッシュしてしまうため、一時的にキューの使用を止めています。
        /*
        captureSessionQueue.async { [weak self] in
            if let finished = self?.configurationFinished, !finished {
                self?.configureCaptureSession()
            }
            self?.captureSession.startRunning()
        }
        */
        if !configurationFinished {
            configureCaptureSession()
        }
        captureSession.startRunning()
        
        // 配信画面に遷移してきたら、videoViewをvideoRendererに設定することで、配信者側の動画を画面に表示させます。
        SoraSDKManager.shared.currentMediaChannel?.senderStream?.videoRenderer = videoView
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // captureSessionを停止します。
        // 注: iOS14 で以下のコードを実行するとクラッシュしてしまうため、一時的にキューの使用を止めています。
        /*
        captureSessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
         */
        captureSession.stopRunning()

        // 配信画面を何らかの理由で抜けることになったら、videoRendererをnilに戻すことで、videoViewへの動画表示をストップさせます。
        SoraSDKManager.shared.currentMediaChannel?.senderStream?.videoRenderer = nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // 画面が回転するときに、カメラキャプチャが出力する動画の向きを都度設定します。
        updateVideoOrientationUsingDeviceOrientation()
    }
    
    // MARK: Actions
    
    /**
     カメラボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onCameraButton(_ sender: UIBarButtonItem) {
        switch captureDevicePosition {
        case .front:
            captureDevicePosition = .back
            // 注: iOS14 で以下のコードを実行するとクラッシュしてしまうため、一時的にキューの使用を止めています。
            /*
            captureSessionQueue.async { [weak self] in
                self?.captureSession.stopRunning()
                self?.configureCaptureSession()
                self?.captureSession.startRunning()
            }
             */
            captureSession.stopRunning()
            configureCaptureSession()
            captureSession.startRunning()
        case .back:
            captureDevicePosition = .front
        // 注: iOS14 で以下のコードを実行するとクラッシュしてしまうため、一時的にキューの使用を止めています。
            /*
            captureSessionQueue.async { [weak self] in
                self?.captureSession.stopRunning()
                self?.configureCaptureSession()
                self?.captureSession.startRunning()
            }
             */
            captureSession.stopRunning()
            configureCaptureSession()
            captureSession.startRunning()
        default:
            break
        }
    }
    
    /**
     フィルタ選択ボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onFilterButton(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: "フィルタを選択", message: nil, preferredStyle: .actionSheet)
        for (name, filter) in PublisherVideoViewController.allFilters {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in self?.currentFilter = filter }
            alertController.addAction(action)
        }
        present(alertController, animated: true, completion: nil)
    }
    
    /**
     閉じるボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onExitButton(_ sender: UIBarButtonItem) {
        // 閉じるボタンを押してもいきなり画面を閉じるのではなく、明示的に配信をストップしてから、画面を閉じるようにしています。
        SoraSDKManager.shared.disconnect()
        performSegue(withIdentifier: "Exit", sender: self)
    }
    
    // MARK: Private Methods
    
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
        guard let captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: captureDevicePosition) else {
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
        self.updateVideoOrientationUsingStatusBarOrientation()
        
    }
    
    /**
     現在のUI上のステータスバーの向きを元に、映像の回転方向を補正します。
     こちらのメソッドはデバイスの画面が天頂向き・地面向きの状態であったとしても、ステータスバーの向きを基準に映像を回転させることができますが、
     その代わりにデバイス画面が天頂向き・地面向きの状態で使用すると意図しない向きに画面が回ってしまう可能性もあります。
     そこで本サンプルでは最初の1回目の補正にのみ使用しています。
     */
    private func updateVideoOrientationUsingStatusBarOrientation() {
        DispatchQueue.main.async {
            let statusBarOrientation = UIApplication.shared.statusBarOrientation
            let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) ?? .portrait
            for output in self.captureSession.outputs {
                if let connection = output.connection(with: .video) {
                    connection.videoOrientation = videoOrientation
                }
            }
        }
    }
    
    /**
     現在のデバイス自体の向きを元に、映像の回転方向を補正します。
     こちらのメソッドはデバイスの向きを元に補正するため、デバイス画面が天頂向き・地面向きの状態で使用すると映像を回転させないで終了するようになっています。
     （明示的にどちらかの方向にデバイスが傾けられているときにだけ、映像を回転させます）
     そこで本サンプルではデバイスが回転したときのイベントに合わせて使用しています。
     */
    private func updateVideoOrientationUsingDeviceOrientation() {
        let deviceOrientation = UIDevice.current.orientation
        guard deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
            return
        }
        guard let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) else {
            return
        }
        for output in captureSession.outputs {
            if let connection = output.connection(with: .video) {
                connection.videoOrientation = videoOrientation
            }
        }
    }
    
    // MARK: UIPickerView
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {
        PublisherVideoViewController.allFilters[row].0
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int {
        PublisherVideoViewController.allFilters.count
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentFilter = PublisherVideoViewController.allFilters[row].1
    }
    
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension PublisherVideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /**
     ビデオキャプチャが、新しいフレームをキャプチャしたときに呼び出されます。
     
     このサンプルアプリでは、キャプチャされたフレームを適切に変換してSora SDKのmediaStreamに流すことで、配信を行っています。
     注意点として、このdelegate methodはパフォーマンス維持のため、
     メインスレッド以外のスレッド (具体的にはcaptureSessionQueue上) にて呼び出されます。
     したがってメインスレッド上で直接操作する必要があるコードを呼び出す場合は注意が必要です。
     */
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let mediaChannel = SoraSDKManager.shared.currentMediaChannel,
            let mediaStream = mediaChannel.senderStream else {
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
    
    /**
     ビデオキャプチャが、何らかの理由でフレーム落ちしたときに呼び出されます。
     */
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // このサンプルアプリでは何もしません。
    }
}
