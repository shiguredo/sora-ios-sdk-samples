import Foundation
import Sora

public class VideoPiPMixer: VideoNode {
    public var localNode: VideoNode?
    public var remoteNodes: [VideoNode] = []

    override public init() {
        super.init()
    }

    override public func processFrameBuffer(_ buffer: VideoFrameBuffer?, in context: VideoGraph.Context) async -> VideoFrameBuffer? {
        print("PiPMixer.process")
        return buffer
    }
}
