import Foundation
import Sora

class VideoGraphManager {
    static var shared: VideoGraphManager = .init()

    var graph: VideoGraph
    var videoViewOutputNode: VideoViewOutputNode
    var decorationNode: VideoCIFilterNode
    var fadeOutNode: VideoColorMonochromeFadeOutNode
    var pipMixerNode: VideoPiPMixer
    var streamOutputNode: VideoStreamOutputNode

    init() {
        graph = VideoGraph()
        videoViewOutputNode = VideoViewOutputNode()
        decorationNode = VideoCIFilterNode()
        fadeOutNode = VideoColorMonochromeFadeOutNode()
        // 負荷を軽くするため、使用時以外は無効にしておく
        fadeOutNode.mode = .passthrough
        pipMixerNode = VideoPiPMixer()
        streamOutputNode = VideoStreamOutputNode()

        graph.attach(graph.cameraInputNode)
        graph.attach(videoViewOutputNode)
        graph.attach(decorationNode)
        graph.attach(fadeOutNode)
        graph.attach(pipMixerNode)
        graph.attach(streamOutputNode)
        graph.connect(graph.cameraInputNode, to: fadeOutNode, format: nil)
        graph.connect(fadeOutNode, to: pipMixerNode, format: nil)
        graph.connect(pipMixerNode, to: videoViewOutputNode, format: nil)
        pipMixerNode.localNode = graph.cameraInputNode
    }

    func start() {
        guard !graph.isRunning else {
            return
        }

        NSLog("run videograph")
        Task {
            await self.graph.start()
        }
    }
}
