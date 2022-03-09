import Foundation
import Sora

class VideoGraphManager {
    static var shared: VideoGraphManager = .init()

    var graph: VideoGraph
    var videoViewOutputNode: VideoViewOutputNode?
    var decoNode: VideoDecoNode

    init() {
        graph = VideoGraph()
        decoNode = VideoDecoNode()
        graph.attach(decoNode)
    }

    func setUp() {
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
