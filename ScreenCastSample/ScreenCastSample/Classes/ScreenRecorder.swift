import AVFoundation
import QuartzCore
import Sora
import UIKit
import WebRTC

class ScreenRecorder {
  let frameRendererQueue = DispatchQueue(
    label: "ScreenCastSample.ScreenRenderer.frameRendererQueue", qos: .userInteractive)
  var frameRendererSemaphore = DispatchSemaphore(value: 1)
  var displayLink: CADisplayLink?
  var outputBufferPool: CVPixelBufferPool?
  var outputColorSpace: CGColorSpace?
  var inputViewSize: CGSize = .zero
  var inputScale: CGFloat = 1.0

  var firstTimestamp: CFTimeInterval = 0

  var captureHandler: ((VideoFrame) -> Void)?

  func startCapture(handler: ((VideoFrame) -> Void)?) {
    guard displayLink == nil else {
      return
    }
    captureHandler = handler
    setupOutputBuffer()
    displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
    displayLink?.preferredFramesPerSecond = 15  // 15FPSで描画するように指定しています。
    displayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
  }

  func stopCapture() {
    if let displayLink {
      displayLink.remove(from: RunLoop.main, forMode: RunLoop.Mode.common)
    }
    displayLink = nil
    firstTimestamp = 0
    cleanupOutputBuffer()
  }

  @objc
  private func onDisplayLink(_ displayLink: CADisplayLink) {
    // displayLink側に指定したFPSの時間内にフレームのレンダリングが終わっていない場合はこのセマフォでブロックして、フレームの描画をスキップします。
    // このスキップを含めないとどんどんフレームのレンダリングが滞留して遅延していき、最終的には固まってしまいます。
    // またここから先の実行は専用のQueue上で実行させ、少しでもパフォーマンスを稼ぎます。
    guard frameRendererSemaphore.wait(timeout: DispatchTime.now()) == .success else {
      return
    }
    frameRendererQueue.async {
      defer {
        self.frameRendererSemaphore.signal()
      }

      // レンダリングに使うピクセルバッファと、ビットマップコンテキストの準備をします。
      guard let pixelBufferPool = self.outputBufferPool,
        let colorSpace = self.outputColorSpace
      else {
        return
      }

      var pb: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pb)
      guard let pixelBuffer = pb else {
        return
      }
      CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
      defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
      }

      guard
        let bitmapContext = CGContext.init(
          data: CVPixelBufferGetBaseAddress(pixelBuffer),
          width: CVPixelBufferGetWidth(pixelBuffer),
          height: CVPixelBufferGetHeight(pixelBuffer),
          bitsPerComponent: 8,
          bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
          space: colorSpace,
          bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue)
      else {
        return
      }
      bitmapContext.scaleBy(x: self.inputScale, y: self.inputScale)
      bitmapContext.concatenate(
        CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: self.inputViewSize.height))  // 縦方向反転用のTransformを適用する。CGContextの座標系は左下基準なので、上下反転させる必要がある。

      // 現在のフレーム時間を計算します。
      if !(self.firstTimestamp > 0) {
        self.firstTimestamp = displayLink.timestamp
      }
      let elapsed = displayLink.timestamp - self.firstTimestamp
      let time = CMTimeMakeWithSeconds(elapsed, preferredTimescale: 1000)

      // UIWindowヒエラルキーをメインスレッド上でレンダリングさせ、その結果を待ちます。
      DispatchQueue.main.sync {
        UIGraphicsPushContext(bitmapContext)
        defer {
          UIGraphicsPopContext()
        }
        for window in UIApplication.shared.windows {
          window.drawHierarchy(
            in: CGRect(origin: .zero, size: self.inputViewSize),
            afterScreenUpdates: false)
        }
      }

      // レンダリング完了したので、コールバックにVideoFrameを返します。
      self.captureHandler?(self.createViewFrame(pixelBuffer: pixelBuffer, time: time))
    }
  }

  private func setupOutputBuffer() {
    guard outputBufferPool == nil else {
      return
    }
    guard let mainWindow = UIApplication.shared.keyWindow else {
      return
    }
    inputViewSize = mainWindow.bounds.size
    inputScale = 1.0  // UIScreen.main.scale のほうが良いのだが、3x Retinaのような巨大な画面で実行するとあまりにも遅すぎるので、一律1.0倍にしてます。

    let attributes =
      [
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue as Any,
        kCVPixelBufferWidthKey: (inputViewSize.width * inputScale) as CFNumber,
        kCVPixelBufferHeightKey: (inputViewSize.height * inputScale) as CFNumber,
        kCVPixelBufferBytesPerRowAlignmentKey: (inputViewSize.width * inputScale * 4)
          as CFNumber,
      ] as CFDictionary
    CVPixelBufferPoolCreate(nil, nil, attributes, &outputBufferPool)

    outputColorSpace = CGColorSpaceCreateDeviceRGB()
  }

  private func cleanupOutputBuffer() {
    outputBufferPool = nil
    outputColorSpace = nil
    inputViewSize = .zero
    inputScale = 1.0
  }

  private func createViewFrame(pixelBuffer: CVPixelBuffer, time: CMTime) -> VideoFrame {
    let timeStamp = CMTimeGetSeconds(time)
    let timeStampNs = Int64(timeStamp * 1_000_000_000)
    let frame = RTCVideoFrame(
      buffer: RTCCVPixelBuffer(pixelBuffer: pixelBuffer),
      rotation: RTCVideoRotation._0,
      timeStampNs: timeStampNs)
    return VideoFrame.native(capturer: nil, frame: frame)
  }
}
