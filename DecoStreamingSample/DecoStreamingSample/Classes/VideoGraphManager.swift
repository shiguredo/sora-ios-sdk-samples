import Foundation
import Sora

class VideoGraphManager {
    static var shared: VideoGraphManager = .init()

    var graph: VideoGraph
    var decoNode: VideoCIFilterNode
    var videoViewOutputNode: VideoViewOutputNode
    var streamOutputNode: VideoStreamOutputNode

    init() {
        graph = VideoGraph()
        decoNode = VideoCIFilterNode()
        videoViewOutputNode = VideoViewOutputNode()
        streamOutputNode = VideoStreamOutputNode()
        graph.attach(graph.cameraInputNode)
        graph.attach(decoNode)
        graph.attach(videoViewOutputNode)
        graph.attach(streamOutputNode)
        graph.connect(graph.cameraInputNode, to: decoNode, format: nil)
        graph.connect(decoNode, to: videoViewOutputNode, format: nil)
        graph.connect(decoNode, to: streamOutputNode, format: nil)
    }

    func start() {
        guard !graph.isRunning else {
            return
        }

        Task {
            await self.graph.start()
        }
    }
}
