import Foundation
import Sora
import WebRTC

class VideoDecoNode: VideoNode {
    var currentFilter: CIFilter?
    private var ciContext: CIContext

    override init() {
        ciContext = CIContext(options: nil)
        super.init()
    }

    override func processFrameBuffer(_ buffer: VideoFrameBuffer?, in context: VideoGraph.Context) async -> VideoFrameBuffer? {
        guard let buffer = buffer else {
            return nil
        }
        guard let filter = currentFilter else {
            return buffer
        }

        // フィルタが選択されているので、キャプチャした動画にフィルタをかけて配信させます。
        //
        // フィルタの実装方法について:
        // ここでは一番簡単なCore Imageを使ったフィルタリングを実装しています。
        // 大本のビデオフレームバッファ (CMSampleBuffer) から画像フレームバッファ (CVPixelBuffer) を取りだし、
        // Core ImageのCIImageに変換して、フィルタをかけます。
        // 最後にフィルタリングされたCIImageをCIContext経由で元々の画像フレームバッファ領域に上書きレンダリングしています。
        // 元々の画像フレームバッファ領域に直接上書きしているので、大本のビデオフレームバッファをそのまま引き続き使用することができ、
        // 最終的にはこのビデオフレームバッファをSora SDKの提供するVideoFrameに変換して配信することができます。

        guard let pixelBuffer = buffer.pixelBuffer else {
            return buffer
        }
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        filter.setValue(cameraImage, forKey: kCIInputImageKey)
        guard let filteredImage = filter.outputImage else {
            return buffer
        }
        ciContext = CIContext(options: nil)
        ciContext.render(filteredImage, to: pixelBuffer)
        print("# VideoDecoNode filtered")
        return buffer
    }
}
