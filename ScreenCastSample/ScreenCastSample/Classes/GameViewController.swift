import ReplayKit
import Sora
import UIKit

/// 0.0~1.0の間の乱数を生成する関数です。
private func randomFloat() -> Float {
    Float(arc4random()) / Float(UInt32.max)
}

/// 0.0~1.0の間の乱数を生成する関数です。
private func randomCGFloat() -> CGFloat {
    CGFloat(randomFloat())
}

// MARK: -

/**
 配信されるゲーム画面です。
 */
class GameViewController: UIViewController {
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

    private var ciContext: CIContext?

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI Dynamicsのための設定を行います。
        animator = UIDynamicAnimator(referenceView: view)

        gravity = UIGravityBehavior(items: [])

        collision = UICollisionBehavior(items: [])
        collision.addBoundary(withIdentifier: "Floor" as NSString,
                              from: CGPoint(x: 0, y: view.bounds.height),
                              to: CGPoint(x: view.bounds.width, y: view.bounds.height))
        collision.addBoundary(withIdentifier: "Void" as NSString,
                              from: CGPoint(x: -9999, y: view.bounds.height + 10),
                              to: CGPoint(x: 9999, y: view.bounds.height + 10))
        collision.collisionDelegate = self

        dynamicProperties = UIDynamicItemBehavior(items: [])
        dynamicProperties.density = 1.0
        dynamicProperties.elasticity = 0.5
        dynamicProperties.friction = 0.1

        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(dynamicProperties)

        // 画面タッチ時のアクションを定義します。
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(onViewTapped(_:)))
        view.addGestureRecognizer(tapGR)

        // ナビゲーションバーのボタンの状態を更新します。
        updateBarButtonItems()

        ciContext = CIContext()
    }

    // MARK: - Action

    /**
     画面タッチ時のアクションを定義します。
     */
    @objc
    func onViewTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        // タッチした場所に新しい箱を発生させます。
        let location = gestureRecognizer.location(in: view)
        addBox(at: location)
    }

    /**
     配信開始ボタンが押されたときの挙動を定義します。
     */
    @IBAction
    func onCameraButton(_ sender: UIBarButtonItem) {
        let isConnected = (SoraSDKManager.shared.currentMediaChannel != nil)
        if isConnected {
            // 既に配信中なので何もしなくて良いです。ボタンの状態だけ更新します。
            updateBarButtonItems()
        } else {
            // 配信を開始するため配信設定画面に遷移し、ボタンの状態を更新します。
            performSegue(withIdentifier: "Publish", sender: self)
            updateBarButtonItems()
        }
    }

    /**
     配信停止ボタンが押されたときの挙動を定義します。
     */
    @IBAction
    func onPauseButton(_ sender: UIBarButtonItem) {
        let isConnected = (SoraSDKManager.shared.currentMediaChannel != nil)
        if isConnected {
            handleDisconnect()
        } else {
            // 配信されていないので何もしなくて良いです。ボタンの状態だけ更新します。
            updateBarButtonItems()
        }
    }

    /**
     配信設定画面からのUnwind Segueの着地地点として定義してあります。
     詳細はMain.storyboardの設定をご確認ください。
     */
    @IBAction
    func onUnwindByConnect(_ segue: UIStoryboardSegue) {
        // 接続が完了して配信設定画面から戻ってきたので、画面録画を開始して配信をスタートします。
        // 画面録画のコールバックでは、受け取ったsampleBufferをそのままSoraSDKに渡して配信を行っています。
        //
        // ReplayKitのカメラを使用することもできますが、ここでは使用していません。
        // 使用する場合にはisCameraEnabledを指定した上で、RPScreenRecorder.shared().cameraPreviewViewを画面上に配置してください。
        // またWebRTCのマイクとコンフリクトするため、基本的にはReplayKitのマイクは使用しないでください。
        //
        // 現在、SoraのVideoCodecにH.264を指定して配信すると、配信が途中で止まるバグがあります。
        // (Soraとの接続が遮断されたわけでも、ReplayKitが止まったわけでもないのに、sendしたフレームが配信されない)
        // これはデバイスに一つしか無いH.264ハードウェアエンコーダ/デコーダをReplayKitとWebRTCが同時に奪い合うためではないかと思われますが、詳細は不明です。
        // 現在のところはVP9など他のエンコード形式を使用することで回避してください。
        RPScreenRecorder.shared().isCameraEnabled = false
        RPScreenRecorder.shared().isMicrophoneEnabled = false
        RPScreenRecorder.shared().startCapture(handler: { sampleBuffer, sampleBufferType, error in
            guard sampleBufferType == .video else {
                return
            }
            guard error == nil else {
                return
            }
            guard let currentMediaChannel = SoraSDKManager.shared.currentMediaChannel,
                  let senderStream = currentMediaChannel.senderStream
            else {
                return
            }

            // H.264 の場合リサイズ
            var bufferToSend = sampleBuffer
            if currentMediaChannel.configuration.videoCodec == .h264 {
                if let resizedBuffer = resizeSampleBuffer(sampleBuffer,
                                                          scale: 0.5,
                                                          ciContext: self.ciContext!)
                {
                    bufferToSend = resizedBuffer
                }
            }
            senderStream.send(videoFrame: VideoFrame(from: bufferToSend))
        }, completionHandler: { [weak self] error in
            if let error = error {
                // エラーが発生して画面録画が開始できなかった場合は、Soraへの配信を停止する必要があります。
                // 例えばユーザーが画面録画を許可しなかった場合などもこのエラーが発生します。
                NSLog("[sample] Error while RPScreenRecorder.shared().startCapture: \(error)")
                self?.handleDisconnect()
            } else if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
                // サーバーから切断されたときのコールバックを設定します。
                mediaChannel.handlers.onDisconnect = { [weak self] _ in
                    NSLog("[sample] mediaChannel.handlers.onDisconnect")
                    self?.handleDisconnect()
                }
            }
        })
        updateBarButtonItems()
    }

    /**
     接続が切断されたときに呼び出されるべき処理をまとめています。
     この切断は、能動的にこちらから切断した場合も、受動的に何らかのエラーなどが原因で切断されてしまった場合も、
     いずれの場合も含めます。
     */
    private func handleDisconnect() {
        // 画面録画中であれば録画を停止して、配信を切断し、ボタンの状態を更新します。
        if RPScreenRecorder.shared().isRecording {
            RPScreenRecorder.shared().stopCapture { _ in
                // エラー時処理を行う必要が無いので、無視します。
            }
        }

        // 明示的に配信をストップしてから、画面を閉じるようにしています。
        SoraSDKManager.shared.disconnect()
        DispatchQueue.main.async { [weak self] in
            self?.updateBarButtonItems()
        }
    }

    /**
     配信設定画面からのUnwind Segueの着地地点として定義してあります。
     詳細はMain.storyboardの設定をご確認ください。
     */
    @IBAction
    func onUnwindByExit(_ segue: UIStoryboardSegue) {
        // 単純に閉じるボタンで配信設定画面を閉じただけなので、特に処理は何も行いません。
    }

    // MARK: - Private

    /**
     ゲーム用の実装です。指定された地点に箱を追加します。
     */
    private func addBox(at point: CGPoint) {
        let box = UIView(frame: CGRect(x: point.x, y: point.y, width: 64, height: 64))
        box.backgroundColor = UIColor(hue: randomCGFloat(), saturation: randomCGFloat(), brightness: randomCGFloat(), alpha: 1.0)
        view.addSubview(box)
        gravity.addItem(box)
        collision.addItem(box)
        dynamicProperties.addItem(box)
    }

    /**
     ゲーム用の実装です。箱を削除します。
     */
    private func removeBox(_ box: UIView) {
        box.removeFromSuperview()
        gravity.removeItem(box)
        collision.removeItem(box)
        dynamicProperties.removeItem(box)
    }

    /**
     現在の配信状態に応じてナビゲーションバーのボタンの状態を更新します。
     */
    private func updateBarButtonItems() {
        let isConnected = (SoraSDKManager.shared.currentMediaChannel != nil)
        if isConnected {
            navigationItem.rightBarButtonItems = [pauseButton]
        } else {
            navigationItem.rightBarButtonItems = [cameraButton]
        }
    }
}

// MARK: - UICollisionBehaviorDelegate

extension GameViewController: UICollisionBehaviorDelegate {
    /**
     ゲーム用の実装です。箱がバウンダリに接触したときの挙動を定義します。
     ここでは画面外バウンダリに箱が接触したときに箱を削除しています。
     */
    func collisionBehavior(_ behavior: UICollisionBehavior, beganContactFor item: UIDynamicItem, withBoundaryIdentifier identifier: NSCopying?, at p: CGPoint) {
        guard let boundaryName = identifier as? String else {
            fatalError()
        }
        switch boundaryName {
        case "Void":
            if let box = item as? UIView {
                removeBox(box)
            }
        default:
            break
        }
    }
}

// https://github.com/shiguredo/sora-ios-sdk/issues/34
// https://fromatom.hatenablog.com/entry/2019/10/28/172628
private func resizeSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                scale: CGFloat,
                                ciContext: CIContext) -> CMSampleBuffer?
{
    // CMSampleTimingInfo を取得する
    // リサイズ後の CMSampleBuffer の生成に使う
    let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    let duration = CMSampleBufferGetDuration(sampleBuffer)
    let decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
    var timingInfo = CMSampleTimingInfo(duration: duration,
                                        presentationTimeStamp: presentationTimeStamp,
                                        decodeTimeStamp: decodeTimeStamp)

    // CIImage をリサイズする
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        NSLog("cannot get pixel buffer")
        return nil
    }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

    guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
        NSLog("not found filter")
        return nil
    }
    filter.setDefaults()
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(scale, forKey: kCIInputScaleKey)
    guard let resizedCIImage = filter.outputImage else {
        NSLog("resize CIImage failed")
        return nil
    }

    // リサイズした CIImage を使って CVPixelBuffer を生成する
    let attrs = [kCVPixelFormatCGImageCompatibility: kCFBooleanTrue,
                 kCVPixelFormatCGBitmapContextCompatibility: kCFBooleanTrue] as CFDictionary
    var newPixelBuffer: CVPixelBuffer!
    var status = CVPixelBufferCreate(nil,
                                     Int(resizedCIImage.extent.size.width),
                                     Int(resizedCIImage.extent.size.height),
                                     kCVPixelFormatType_32BGRA,
                                     attrs,
                                     &newPixelBuffer)
    guard status == kCVReturnSuccess else {
        NSLog("cannot create new pixel buffer \(status)")
        return nil
    }
    ciContext.render(resizedCIImage,
                     to: newPixelBuffer,
                     bounds: resizedCIImage.extent,
                     colorSpace: CGColorSpaceCreateDeviceRGB())
    status = CVPixelBufferLockBaseAddress(newPixelBuffer, .readOnly)
    guard status == kCVReturnSuccess else {
        NSLog("cannot render to new pixel buffer \(status)")
        return nil
    }

    // CVPixelBuffer から CMSampleBuffer を生成する
    // 最初に取得しておいた CMSampleTimingInfo を使う
    var newSampleBuffer: CMSampleBuffer!
    var videoInfo: CMVideoFormatDescription!

    status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
                                                          imageBuffer: newPixelBuffer,
                                                          formatDescriptionOut: &videoInfo)
    guard status == errSecSuccess else {
        NSLog("cannot create video format description \(status)")
        return nil
    }

    status = CMSampleBufferCreateForImageBuffer(allocator: nil,
                                                imageBuffer: newPixelBuffer,
                                                dataReady: true,
                                                makeDataReadyCallback: nil,
                                                refcon: nil,
                                                formatDescription: videoInfo,
                                                sampleTiming: &timingInfo,
                                                sampleBufferOut: &newSampleBuffer)
    guard status == errSecSuccess else {
        NSLog("cannot create new sample buffer \(status)")
        return nil
    }

    return newSampleBuffer
}
