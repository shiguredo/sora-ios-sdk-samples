import AVFoundation
import UIKit

/// AVFoundationの機能を用いて、カメラがキャプチャしている現在の映像をそのままプレビューとして表示するためのビューです。
/// このビューはあくまでカメラがキャプチャしている映像のプレビューのみを表示することができ、外部で加工されたCVPixelBufferを表示することはできません。
/// 現在Sora SDKによって配信されている映像をそのまま表示したい場合には、Sora.VideoViewを使用してください。
class AVCaptureVideoPreviewView: UIView {
  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var previewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
  }

  func updateVideoOrientationUsingStatusBarOrientation() {
    let statusBarOrientation = UIApplication.shared.statusBarOrientation
    let videoOrientation =
      AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) ?? .portrait
    previewLayer.connection?.videoOrientation = videoOrientation
  }

  func updateVideoOrientationUsingDeviceOrientation() {
    let deviceOrientation = UIDevice.current.orientation
    guard deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
      return
    }
    guard let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation)
    else {
      return
    }
    previewLayer.connection?.videoOrientation = videoOrientation
  }
}
