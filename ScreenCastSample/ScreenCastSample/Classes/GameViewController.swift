import UIKit
import ReplayKit
import Sora

/// 0.0~1.0の間の乱数を生成する関数です。
private func randomFloat() -> Float {
    return Float(arc4random()) / Float(UInt32.max)
}

/// 0.0~1.0の間の乱数を生成する関数です。
private func randomCGFloat() -> CGFloat {
    return CGFloat(randomFloat())
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
            // 画面録画を停止して、配信を切断し、ボタンの状態を更新します。
            RPScreenRecorder.shared().stopCapture { error in
                // エラー時処理を行う必要が無いので、無視します。
            }
            SoraSDKManager.shared.disconnect()
            updateBarButtonItems()
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
                let mainStream = currentMediaChannel.mainStream else {
                    return
            }
            mainStream.send(videoFrame: VideoFrame(from: sampleBuffer))
        }, completionHandler: { [weak self] error in
            if let error = error {
                // エラーが発生して画面録画が開始できなかった場合は、Soraへの配信を停止する必要があります。
                // 例えばユーザーが画面録画を許可しなかった場合などもこのエラーが発生します。
                NSLog("Error while RPScreenRecorder.shared().startCapture: \(error)")
                SoraSDKManager.shared.disconnect()
                DispatchQueue.main.async {
                    self?.updateBarButtonItems()
                }
            }
        })
        updateBarButtonItems()
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
