import Foundation

enum RPCEnvironment {
  // 接続するサーバーのシグナリング URL
  static var urls: [URL] { Environment.urls }

  // チャネル ID
  static var channelId: String { Environment.channelId }

  // type: connect に含めるメタデータ
  static var signalingConnectMetadata: Encodable? { Environment.signalingConnectMetadata }
}

enum RPCSignalingParser {
  static func parseOfferRPCMethods(from json: String) -> [String]? {
    guard let data = json.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data, options: []),
      let dictionary = object as? [String: Any],
      dictionary["type"] as? String == "offer"
    else {
      return nil
    }
    return dictionary["rpc_methods"] as? [String]
  }
}
