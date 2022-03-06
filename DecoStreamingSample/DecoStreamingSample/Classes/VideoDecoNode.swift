import Foundation
import Sora
import WebRTC

class VideoDecoNode: VideoNode {
    var currentFilter: CIFilter?

    override init() {
        super.init()
    }

    override func renderFrame(_ frame: VideoFrameBuffer?) -> VideoFrameBuffer? {
        guard let frame = frame else {
            return nil
        }
        guard let filter = currentFilter else {
            return frame
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

        guard let nativePixelBuffer = frame.nativeFrame?.buffer as? RTCCVPixelBuffer else {
            return frame
        }
        let pixelBuffer = nativePixelBuffer.pixelBuffer
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        filter.setValue(cameraImage, forKey: kCIInputImageKey)
        guard let filteredImage = filter.outputImage else {
            return frame
        }
        let context = CIContext(options: nil)
        context.render(filteredImage, to: pixelBuffer)
        print("# VideoDecoNode filtered")
        return frame
    }
}
