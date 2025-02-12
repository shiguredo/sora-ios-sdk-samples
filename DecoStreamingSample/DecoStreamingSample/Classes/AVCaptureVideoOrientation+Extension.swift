import AVFoundation
import UIKit

/// サンプルアプリ内で使うための、便利なExtensionを定義します。
extension AVCaptureVideoOrientation {
  /**
     UIDeviceOrientationを元にAVCaptureVideoOrientationを返します。
     */
  init?(deviceOrientation: UIDeviceOrientation) {
    switch deviceOrientation {
    case .portrait: self = .portrait
    case .portraitUpsideDown: self = .portraitUpsideDown
    case .landscapeLeft: self = .landscapeRight
    case .landscapeRight: self = .landscapeLeft
    default: return nil
    }
  }

  /**
     UIInterfaceOrientationを元にAVCaptureVideoOrientationを返します。
     */
  init?(interfaceOrientation: UIInterfaceOrientation) {
    switch interfaceOrientation {
    case .portrait: self = .portrait
    case .portraitUpsideDown: self = .portraitUpsideDown
    case .landscapeLeft: self = .landscapeLeft
    case .landscapeRight: self = .landscapeRight
    default: return nil
    }
  }
}
