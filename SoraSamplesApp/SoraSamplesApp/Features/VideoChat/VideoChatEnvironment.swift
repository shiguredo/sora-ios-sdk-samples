import Foundation

enum VideoChatEnvironment {
    static var urls: [URL] { Environment.urls }
    static var channelId: String { Environment.channelId }
    static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }
}
