import AVFoundation
import Sora
import UIKit

/**
 実際に動画を配信する画面です。
 */
class PublisherVideoViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var filterPickerView: UIPickerView!

    @IBOutlet weak var filterPickerViewHeightArchorPad: NSLayoutConstraint!
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
            ("マンガ調", comicFilter),
        ]
    }()

    /// 配信者側の動画を画面に表示するためのビューです。Main.storyboardから設定されていますので、詳細はそちらをご確認ください。
    @IBOutlet private var videoView: VideoView!

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
            filterPickerViewHeightArchorPad.isActive = false
            filterPickerView.heightAnchor.constraint(equalToConstant: 0).isActive = true
        }

        // VideoView 出力ノードにビューをセットする
        // ノードに渡された映像が VideoView で描画されるようになる
        VideoGraphManager.shared.videoViewOutputNode.videoView = videoView
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

        // グラフを開始する
        // 開始処理は非同期で実行される
        let manager = VideoGraphManager.shared
        manager.start()

        // ストリーム出力ノードに配信ストリームをセットする
        // ノードに渡された映像が配信ストリームにより Sora に送信される
        if let stream = SoraSDKManager.shared.currentMediaChannel?.mainStream {
            manager.streamOutputNode.stream = stream
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 他の画面に切り替わる場合は、グラフを停止＆ストリームをクリアして、映像の描画と配信を停止する
        let manager = VideoGraphManager.shared
        manager.stop()
        manager.streamOutputNode.stream = nil
    }

    // MARK: Actions

    /**
     カメラボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onCameraButton(_ sender: UIBarButtonItem) {
        // カメラの位置を切り替える
        if let capturer = CameraVideoCapturer.current {
            CameraVideoCapturer.flip(capturer) { _ in }
        }
    }

    /**
     フィルタ選択ボタンを押したときの挙動を定義します。
     詳しくはMain.storyboard内の定義をご覧ください。
     */
    @IBAction func onFilterButton(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: "フィルタを選択", message: nil, preferredStyle: .actionSheet)
        for (name, filter) in PublisherVideoViewController.allFilters {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in
                // 選択されたフィルターを加工ノードにセットする
                VideoGraphManager.shared.decoNode.filter = filter
            }
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

    // MARK: UIPickerView

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String?
    {
        PublisherVideoViewController.allFilters[row].0
    }

    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int
    {
        PublisherVideoViewController.allFilters.count
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentFilter = PublisherVideoViewController.allFilters[row].1
    }
}
