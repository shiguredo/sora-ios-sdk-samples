import CoreImage
import Foundation
import Sora

public class VideoPiPMixer: VideoNode {
    public var mainNode: VideoNode?
    public var subnode: VideoNode?

    public var subnodeScale: Double = 0.4

    private var transform: CIFilter
    private var sourceOverCompositing: CIFilter
    private var lastBuffer: VideoFrameBuffer?
    private var lastSubImage: CIImage?

    override public init() {
        transform = CIFilter(name: "CILanczosScaleTransform")!
        sourceOverCompositing = CIFilter(name: "CISourceOverCompositing")!
        super.init()
    }

    override public func processFrameBuffer(_ buffer: VideoFrameBuffer?, in context: VideoGraph.Context) async -> VideoFrameBuffer? {
        guard let buffer = buffer else {
            return nil
        }
        guard let pixelBuffer = buffer.pixelBuffer else {
            // TODO: 受信ストリームで pixel buffer を取得できない
            // RTCI420Buffer になってる
            print("# no pixel buffer ")
            switch buffer {
            case let .native(frame):
                print("# native buffer = \(frame.buffer)")
            default:
                break
            }
            return buffer
        }

        if context.source == mainNode {
            print("# check main node")
            lastBuffer = buffer

            // サブ画像を合成する
            // なければ何もしない
            guard let lastSubImage = lastSubImage else {
                return buffer
            }

            let mainImage = CIImage(cvPixelBuffer: pixelBuffer)
            sourceOverCompositing.setValue(lastSubImage, forKey: kCIInputImageKey)
            sourceOverCompositing.setValue(mainImage, forKey: kCIInputBackgroundImageKey)
            guard let compositedImage = sourceOverCompositing.outputImage else {
                return buffer
            }
            let ciContext = CIContext(options: nil)
            ciContext.render(compositedImage, to: pixelBuffer)
            return buffer
        } else if context.source == subnode {
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            transform.setValue(image, forKey: kCIInputImageKey)
            transform.setValue(subnodeScale, forKey: kCIInputScaleKey)
            guard let filteredImage = transform.outputImage else {
                return buffer
            }

            // 縮小して切り出す
            let width = Double(CVPixelBufferGetWidth(pixelBuffer)) * subnodeScale
            let baseHeight = Double(CVPixelBufferGetHeight(pixelBuffer))
            let height = baseHeight * subnodeScale
            let rect = CGRect(x: 0, y: baseHeight, width: width, height: height)
            let cropped = filteredImage.cropped(to: rect)
            lastSubImage = cropped

            // メイン画面と合成する
            // TODO: 最後の映像がない場合は黒く塗りつぶす？
            guard let lastPixelBuffer = lastBuffer?.pixelBuffer else {
                return buffer
            }
            let mainImage = CIImage(cvPixelBuffer: lastPixelBuffer)
            sourceOverCompositing.setValue(cropped, forKey: kCIInputImageKey)
            sourceOverCompositing.setValue(mainImage, forKey: kCIInputBackgroundImageKey)
            guard let compositedImage = sourceOverCompositing.outputImage else {
                return buffer
            }
            // TODO: CIContext は再利用可能？
            let ciContext = CIContext(options: nil)
            ciContext.render(compositedImage, to: pixelBuffer)
            return buffer
        } else {
            print("# unknown node \(context.source)")
            // 知らないノードからの映像であれば無視する
            return buffer
        }
    }
}
