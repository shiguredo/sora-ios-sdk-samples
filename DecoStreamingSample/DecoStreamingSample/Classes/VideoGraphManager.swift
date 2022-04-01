import Foundation
import Sora

// アプリケーションで共有する映像グラフを管理するクラス
// このようなクラスを必ずしも用意する必要はないが、 UI と分けておくと管理しやすい
class VideoGraphManager {
    static var shared: VideoGraphManager = .init()

    var graph: VideoGraph
    var decoNode: VideoCIFilterNode
    var videoViewOutputNode: VideoViewOutputNode
    var streamOutputNode: VideoStreamOutputNode

    init() {
        // グラフを生成する
        graph = VideoGraph()

        // 映像を加工するためのノードを生成する
        // VideoCIFilterNode はサンプルで SDK 外のもの
        decoNode = VideoCIFilterNode()

        // 映像を VideoView に出力するノード
        videoViewOutputNode = VideoViewOutputNode()

        // 映像をストリームに出力 (配信) するノード
        streamOutputNode = VideoStreamOutputNode()

        // グラフで使用するノードを登録する
        graph.attach(graph.cameraInputNode)
        graph.attach(decoNode)
        graph.attach(videoViewOutputNode)
        graph.attach(streamOutputNode)

        // ノード同士を接続する
        // カメラから映像を取得するノードと映像を加工するノードを接続し、カメラの映像を加工する
        // 加工ノードが加工した映像は、加工ノードに接続したノードすべてに渡される
        graph.connect(graph.cameraInputNode, to: decoNode)

        // 加工ノードと VideoView ノードを接続し、加工した映像を VideoView に渡す
        graph.connect(decoNode, to: videoViewOutputNode)

        // 加工ノードとストリーム出力ノードを接続し、加工した映像を配信ストリームに渡す
        graph.connect(decoNode, to: streamOutputNode)
    }

    // グラフの処理を開始する
    func start() {
        // すでに実行中であれば無視
        guard !graph.isRunning else {
            return
        }

        // グラフの処理を開始する
        // async/await 対応の API を呼ぶため、 Task でラップする
        // Task 内は非同期で実行されるので、処理の終了を待たずに本メソッドは終了する
        // Task でラップしない場合、本メソッドを async で宣言し await で呼び出す必要がある
        // 本サンプルではグラフ開始の完了まで待つ必要がないので非同期で処理する
        Task {
            // VideoGraph.start() は非同期処理として定義している (async) ので await が必要
            // これ以降に処理を記述した場合、グラフ開始完了してから実行される
            await self.graph.start()
        }
    }

    // 実行中のグラフを停止する
    func stop() {
        // 実行中でなければ何もしない
        guard graph.isRunning else {
            return
        }

        Task {
            // グラフを停止する
            await graph.stop()
        }
    }
}
