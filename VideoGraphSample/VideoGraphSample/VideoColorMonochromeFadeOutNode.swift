import Foundation
import Sora

public class VideoColorMonochromeFadeOutNode: VideoNode {
    public var filter: CIFilter
    public var timeInterval: TimeInterval = 0.07
    public var inputIntensityRate: Double = 0.5
    public var maxInputIntensity: Double = 5
    public var inputColor: CIColor = .black

    private var inputIntensity: Double = 0.0
    private var timer: Timer?
    private var inFadeOut = false

    override public init() {
        filter = CIFilter(name: "CIColorMonochrome")!
        super.init()
    }

    private typealias FadeOutContinuation = CheckedContinuation<Void, Never>

    public func startFadeOut() async {
        await withCheckedContinuation { (continuation: FadeOutContinuation) in
            inputIntensity = 0.0
            filter.setValue(inputColor, forKey: kCIInputColorKey)
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
                self.filter.setValue(self.inputIntensity, forKey: kCIInputIntensityKey)
                self.inputIntensity += self.inputIntensityRate
                if self.inputIntensity > self.maxInputIntensity {
                    self.finishFadeOut(continuation)
                }
            }
            inFadeOut = true
        }
    }

    private func finishFadeOut(_ continuation: FadeOutContinuation) {
        inFadeOut = false
        timer?.invalidate()
        timer = nil
        continuation.resume()
    }

    public func clear() {
        filter.setValue(0, forKey: kCIInputIntensityKey)
    }

    override public func processFrameBuffer(_ buffer: VideoFrameBuffer?, in context: VideoGraph.Context) async -> VideoFrameBuffer? {
        guard inFadeOut else {
            return buffer
        }
        guard let pixelBuffer = buffer?.pixelBuffer else {
            return buffer
        }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        filter.setValue(image, forKey: kCIInputImageKey)
        guard let filteredImage = filter.outputImage else {
            return buffer
        }
        let context = CIContext(options: nil)
        context.render(filteredImage, to: pixelBuffer)
        return buffer
    }
}
