import Foundation
import Sora

class VideoGraphManager {
    static var shared: VideoGraphManager = .init()

    var graph: VideoGraph
    var videoViewOutputNode: VideoViewOutputNode
    var decorationNode: VideoCIFilterNode
    var pipMixerNode: VideoPiPMixer
    var streamOutputNode: VideoStreamOutputNode

    init() {
        graph = VideoGraph()
        videoViewOutputNode = VideoViewOutputNode()
        decorationNode = VideoCIFilterNode()
        pipMixerNode = VideoPiPMixer()
        streamOutputNode = VideoStreamOutputNode()

        graph.attach(graph.cameraInputNode)
        graph.attach(videoViewOutputNode)
        graph.attach(decorationNode)
        graph.attach(pipMixerNode)
        graph.attach(streamOutputNode)
        graph.connect(graph.cameraInputNode, to: pipMixerNode, format: nil)
        graph.connect(pipMixerNode, to: videoViewOutputNode, format: nil)
        pipMixerNode.localNode = graph.cameraInputNode
    }

    func start() {
        guard !graph.isRunning else {
            return
        }

        NSLog("run videograph")
        let device = CameraVideoCapturer.device(for: .front)
        let format = CameraVideoCapturer.format(width: 640, height: 480, for: device!)!
        let capturer = CameraVideoCapturer(device: device!)
        capturer.start(format: format, frameRate: 30) { error in
            print("start capturer")
            guard error == nil else {
                NSLog("error = \(error)")
                return
            }
            Task {
                await self.graph.start()
            }
        }
    }
}
