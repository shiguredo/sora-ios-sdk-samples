import Sora
import UIKit

private let logger = SamplesLogger.tagged("RPCRoom")

// MARK: - RPCMethod Display Helper

private extension RPCMethod {
  var displayName: String {
    switch self {
    case .requestSimulcastRid:
      return "RequestSimulcastRid"
    case .requestSpotlightRid:
      return "RequestSpotlightRid"
    case .resetSpotlightRid:
      return "ResetSpotlightRid"
    case .putSignalingNotifyMetadata:
      return "PutSignalingNotifyMetadata"
    case .putSignalingNotifyMetadataItem:
      return "PutSignalingNotifyMetadataItem"
    }
  }
}

private struct RPCLogItem {
  let timestamp: Date
  let direction: String
  let label: String
  let summary: String
  let detail: String
}

// MARK: - JSON Value helpers for metadata operations

/// Any 型の値をエンコード可能にするラッパー型
private struct AnyCodable: Codable {
  let value: Any

  init(_ value: Any) {
    self.value = value
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let intValue = value as? Int {
      try container.encode(intValue)
    } else if let doubleValue = value as? Double {
      try container.encode(doubleValue)
    } else if let stringValue = value as? String {
      try container.encode(stringValue)
    } else if let boolValue = value as? Bool {
      try container.encode(boolValue)
    } else if let arrayValue = value as? [Any] {
      try container.encode(arrayValue.map(AnyCodable.init))
    } else if let dictValue = value as? [String: Any] {
      let mapped = dictValue.mapValues(AnyCodable.init)
      try container.encode(mapped)
    } else if value is NSNull {
      try container.encodeNil()
    } else {
      throw EncodingError.invalidValue(value, EncodingError.Context(
        codingPath: container.codingPath,
        debugDescription: "AnyCodable cannot encode \(type(of: value))"
      ))
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = NSNull()
    } else if let boolValue = try? container.decode(Bool.self) {
      value = boolValue
    } else if let intValue = try? container.decode(Int.self) {
      value = intValue
    } else if let doubleValue = try? container.decode(Double.self) {
      value = doubleValue
    } else if let stringValue = try? container.decode(String.self) {
      value = stringValue
    } else if let arrayValue = try? container.decode([AnyCodable].self) {
      value = arrayValue.map(\.value)
    } else if let dictValue = try? container.decode([String: AnyCodable].self) {
      value = dictValue.mapValues(\.value)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
    }
  }
}

private final class ResolutionVideoView: UIView, VideoRenderer {
  private let soraVideoView = VideoView()
  var onFrameSizeChanged: ((CGSize) -> Void)?
  private var lastSize: CGSize = .zero

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    soraVideoView.contentMode = .scaleAspectFill
    soraVideoView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(soraVideoView)
    NSLayoutConstraint.activate([
      soraVideoView.leadingAnchor.constraint(equalTo: leadingAnchor),
      soraVideoView.trailingAnchor.constraint(equalTo: trailingAnchor),
      soraVideoView.topAnchor.constraint(equalTo: topAnchor),
      soraVideoView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  // MARK: - VideoRenderer

  func onChange(size: CGSize) {
    soraVideoView.onChange(size: size)
    if size != lastSize {
      lastSize = size
      onFrameSizeChanged?(size)
    }
  }

  func render(videoFrame: VideoFrame?) {
    soraVideoView.render(videoFrame: videoFrame)
    if let videoFrame {
      let newSize = CGSize(width: videoFrame.width, height: videoFrame.height)
      if newSize != lastSize {
        lastSize = newSize
        onFrameSizeChanged?(newSize)
      }
    }
  }

  func onDisconnect(from mediaChannel: MediaChannel?) {
    soraVideoView.onDisconnect(from: mediaChannel)
  }

  func onAdded(from mediaStream: MediaStream) {
    soraVideoView.onAdded(from: mediaStream)
  }

  func onRemoved(from mediaStream: MediaStream) {
    soraVideoView.onRemoved(from: mediaStream)
  }

  func onSwitch(video: Bool) {
    soraVideoView.onSwitch(video: video)
  }

  func onSwitch(audio: Bool) {
    soraVideoView.onSwitch(audio: audio)
  }
}



/// RPC の送受信画面です。
class RPCRoomViewController: UIViewController {
  @IBOutlet weak var historyTableView: UITableView!
  @IBOutlet weak var memberListView: UIView!
  @IBOutlet weak var resolutionLabel: UILabel!
  private let connectedUrlLabel = UILabel()
  private let channelIdLabel = UILabel()
  private let methodButton = UIButton(type: .system)
  private let simulcastRidSegmentedControl = UISegmentedControl(items: ["none", "r0", "r1", "r2"])
  private let senderConnectionIdTextField = UITextField()
  private let pushSwitch = UISwitch()
  private let metadataTextView = UITextView()
  private let rpcMethodsLabel = UILabel()
  private let simulcastRpcRidsLabel = UILabel()
  private let sendRequestButton = UIButton(type: .system)
  private let sendNotificationButton = UIButton(type: .system)
  private var headerView: UIView?
  private var simulcastRowView: UIView?
  private var pushRowView: UIView?
  private var downstreamVideoView: ResolutionVideoView?

  private let availableMethods: [RPCMethod] = [
    .requestSimulcastRid,
    .requestSpotlightRid,
    .resetSpotlightRid,
    .putSignalingNotifyMetadata,
    .putSignalingNotifyMetadataItem
  ]
  private var selectedMethod: RPCMethod = .requestSimulcastRid
  private var logs: [RPCLogItem] = []
  private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    historyTableView.dataSource = self
    historyTableView.delegate = self
    historyTableView.rowHeight = UITableView.automaticDimension
    historyTableView.estimatedRowHeight = 60

    setupHeaderView()
    setupMethodMenu()
    updateMethodUI()

    rpcMethodsLabel.text = "未取得"
    simulcastRpcRidsLabel.text = "未取得"
    resolutionLabel.text = "Resolution: -"
    metadataTextView.text = """
    {
      "example_key_1": "example_value_1"
    }
    """
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let mediaChannel = RPCSoraSDKManager.shared.currentMediaChannel {
      navigationItem.title = mediaChannel.configuration.channelId
      channelIdLabel.text = "Channel ID: \(mediaChannel.configuration.channelId)"
      let urlText = mediaChannel.connectedUrl?.absoluteString ?? "-"
      connectedUrlLabel.text = "Connected URL: \(urlText)"

      mediaChannel.handlers.onDataChannelMessage = { [weak self] _, label, data in
        self?.handleDataChannelMessage(label: label, data: data)
      }

      mediaChannel.handlers.onAddStream = { [weak self] _ in
        DispatchQueue.main.async {
          self?.handleUpdateStreams()
        }
      }

      mediaChannel.handlers.onReceiveSignaling = { [weak self] signaling in
        self?.handleSignaling(signaling)
      }

      mediaChannel.handlers.onDataChannel = { [weak self] mediaChannel in
        self?.updateRPCMethods(using: mediaChannel)
      }

      mediaChannel.handlers.onRemoveStream = { [weak self] _ in
        DispatchQueue.main.async {
          self?.handleUpdateStreams()
        }
      }

      mediaChannel.handlers.onDisconnect = { [weak self] event in
        guard let self = self else { return }
        switch event {
        case .ok(let code, let reason):
          logger.info(
            "[sample] mediaChannel.handlers.onDisconnect: code: \(code), reason: \(reason)")
        case .error(let error):
          logger.error(
            "[sample] mediaChannel.handlers.onDisconnect: error: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
          self.handleDisconnect()
        }
      }

      handleUpdateStreams()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    if let mediaChannel = RPCSoraSDKManager.shared.currentMediaChannel {
      mediaChannel.handlers.onDataChannelMessage = nil
      mediaChannel.handlers.onAddStream = nil
      mediaChannel.handlers.onRemoveStream = nil
      mediaChannel.handlers.onReceiveSignaling = nil
      mediaChannel.handlers.onDataChannel = nil
      mediaChannel.handlers.onDisconnect = nil
    }
  }

  @IBAction func onExitButton(_ sender: Any?) {
    handleDisconnect()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateHeaderLayoutIfNeeded()
    layoutVideoView(for: memberListView.bounds.size)
  }

  @objc private func onSendRequestButton(_ sender: Any?) {
    sendRPC(isNotification: false)
  }

  @objc private func onSendNotificationButton(_ sender: Any?) {
    sendRPC(isNotification: true)
  }

  @objc private func onTapView(_ sender: UITapGestureRecognizer) {
    senderConnectionIdTextField.endEditing(true)
    metadataTextView.endEditing(true)
  }

  private func setupMethodMenu() {
    let actions = availableMethods.map { method in
      UIAction(title: method.displayName, state: method == selectedMethod ? .on : .off) { [weak self] _ in
        self?.selectedMethod = method
        self?.updateMethodUI()
      }
    }
    methodButton.menu = UIMenu(title: "RPC Method", children: actions)
    methodButton.showsMenuAsPrimaryAction = true
  }

  private func updateMethodUI() {
    simulcastRowView?.isHidden = !(selectedMethod == .requestSimulcastRid || selectedMethod == .requestSpotlightRid)
    senderConnectionIdTextField.isHidden = !(
      selectedMethod == .requestSimulcastRid
        || selectedMethod == .requestSpotlightRid
        || selectedMethod == .resetSpotlightRid
    )
    pushRowView?.isHidden = !(
      selectedMethod == .putSignalingNotifyMetadata
        || selectedMethod == .putSignalingNotifyMetadataItem
    )
    metadataTextView.isHidden = !(
      selectedMethod == .putSignalingNotifyMetadata
        || selectedMethod == .putSignalingNotifyMetadataItem
    )
    methodButton.setTitle(selectedMethod.displayName, for: .normal)
    setupMethodMenu()
  }

  private func sendRPC(isNotification: Bool) {
    guard let mediaChannel = RPCSoraSDKManager.shared.currentMediaChannel else {
      return
    }

    Task {
      do {
        switch selectedMethod {
        case .requestSimulcastRid:
          let params = RequestSimulcastRidParams(
            rid: selectedSimulcastRid(),
            senderConnectionId: trimmedSenderConnectionId()
          )
          if isNotification {
            try await mediaChannel.rpc(
              method: RequestSimulcastRid.self,
              params: params,
              isNotificationRequest: true
            )
          } else {
            let response = try await mediaChannel.rpc(
              method: RequestSimulcastRid.self,
              params: params
            )
            if let response = response {
              appendLog(direction: "recv", label: "rpc", summary: "success", detail: stringifyJSON(response.result))
            }
          }
          appendLog(
            direction: isNotification ? "send(notification)" : "send",
            label: "rpc",
            summary: selectedMethod.displayName,
            detail: makeRequestDetail(method: RequestSimulcastRid.name, params: paramsDictionary(from: params))
          )

        case .requestSpotlightRid:
          let params = RequestSpotlightRidParams(
            sendConnectionId: trimmedSenderConnectionId(),
            spotlightFocusRid: selectedSimulcastRid(),
            spotlightUnfocusRid: .none
          )
          if isNotification {
            try await mediaChannel.rpc(
              method: RequestSpotlightRid.self,
              params: params,
              isNotificationRequest: true
            )
          } else {
            let response = try await mediaChannel.rpc(
              method: RequestSpotlightRid.self,
              params: params
            )
            if let response = response {
              appendLog(direction: "recv", label: "rpc", summary: "success", detail: stringifyJSON(response.result))
            }
          }
          appendLog(
            direction: isNotification ? "send(notification)" : "send",
            label: "rpc",
            summary: selectedMethod.displayName,
            detail: makeRequestDetail(method: RequestSpotlightRid.name, params: paramsDictionary(from: params))
          )

        case .resetSpotlightRid:
          let params = ResetSpotlightRidParams(
            sendConnectionId: trimmedSenderConnectionId()
          )
          if isNotification {
            try await mediaChannel.rpc(
              method: ResetSpotlightRid.self,
              params: params,
              isNotificationRequest: true
            )
          } else {
            let response = try await mediaChannel.rpc(
              method: ResetSpotlightRid.self,
              params: params
            )
            if let response = response {
              appendLog(direction: "recv", label: "rpc", summary: "success", detail: stringifyJSON(response.result))
            }
          }
          appendLog(
            direction: isNotification ? "send(notification)" : "send",
            label: "rpc",
            summary: selectedMethod.displayName,
            detail: makeRequestDetail(method: ResetSpotlightRid.name, params: paramsDictionary(from: params))
          )

        case .putSignalingNotifyMetadata:
          let (metadataDict, _) = try parseMetadata()
          let params = PutSignalingNotifyMetadataParams(
            metadata: metadataDict,
            push: pushSwitch.isOn ? true : nil
          )
          if isNotification {
            try await mediaChannel.rpc(
              method: PutSignalingNotifyMetadata<[String: AnyCodable]>.self,
              params: params,
              isNotificationRequest: true
            )
          } else {
            let response = try await mediaChannel.rpc(
              method: PutSignalingNotifyMetadata<[String: AnyCodable]>.self,
              params: params
            )
            if let response = response {
              appendLog(direction: "recv", label: "rpc", summary: "success", detail: stringifyJSON(response.result))
            }
          }
          appendLog(
            direction: isNotification ? "send(notification)" : "send",
            label: "rpc",
            summary: selectedMethod.displayName,
            detail: makeRequestDetail(method: PutSignalingNotifyMetadata<[String: AnyCodable]>.name, params: paramsDictionary(from: params))
          )

        case .putSignalingNotifyMetadataItem:
          let (key, _, value) = try parseMetadataItem()
          let params = PutSignalingNotifyMetadataItemParams<AnyCodable>(
            key: key,
            value: AnyCodable(value),
            push: pushSwitch.isOn ? true : nil
          )
          if isNotification {
            try await mediaChannel.rpc(
              method: PutSignalingNotifyMetadataItem<AnyCodable, AnyCodable>.self,
              params: params,
              isNotificationRequest: true
            )
          } else {
            let response = try await mediaChannel.rpc(
              method: PutSignalingNotifyMetadataItem<AnyCodable, AnyCodable>.self,
              params: params
            )
            if let response = response {
              appendLog(direction: "recv", label: "rpc", summary: "success", detail: stringifyJSON(response.result))
            }
          }
          appendLog(
            direction: isNotification ? "send(notification)" : "send",
            label: "rpc",
            summary: selectedMethod.displayName,
            detail: makeRequestDetail(method: PutSignalingNotifyMetadataItem<AnyCodable, AnyCodable>.name, params: paramsDictionary(from: params))
          )
        }
      } catch {
        logger.error("failed to send RPC: \(error)")
        presentAlert(title: "送信に失敗しました", message: error.localizedDescription)
      }
    }
  }

  private func selectedSimulcastRid() -> Rid {
    let index = simulcastRidSegmentedControl.selectedSegmentIndex
    let rids: [Rid] = [.none, .r0, .r1, .r2]
    return rids.indices.contains(index) ? rids[index] : .none
  }

  private func selectedSimulcastRidString() -> String {
    let index = simulcastRidSegmentedControl.selectedSegmentIndex
    let rids = ["none", "r0", "r1", "r2"]
    return rids.indices.contains(index) ? rids[index] : "none"
  }

  private func trimmedSenderConnectionId() -> String? {
    guard let text = senderConnectionIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty
    else {
      return nil
    }
    return text
  }

  private func paramsDictionary<T: Encodable>(from params: T) -> [String: Any] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = []
    if let data = try? encoder.encode(params),
       let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return dictionary
    }
    return [:]
  }

  private func parseMetadata() throws -> ([String: AnyCodable], [String: Any]) {
    let text = metadataTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty {
      return ([:], [:])
    }
    guard let data = text.data(using: .utf8) else {
      throw NSError(domain: "RPC", code: 1, userInfo: [NSLocalizedDescriptionKey: "JSON の文字列が不正です。"])
    }
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
      throw NSError(domain: "RPC", code: 2, userInfo: [NSLocalizedDescriptionKey: "metadata は JSON オブジェクトで指定してください。"])
    }
    var mapped: [String: AnyCodable] = [:]
    for (key, value) in dictionary {
      mapped[key] = AnyCodable(value)
    }
    return (mapped, dictionary)
  }

  private func parseMetadataItem() throws -> (String, Any, AnyCodable) {
    let text = metadataTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty {
      throw NSError(domain: "RPC", code: 4, userInfo: [NSLocalizedDescriptionKey: "key と value を JSON で指定してください。"])
    }
    guard let data = text.data(using: .utf8) else {
      throw NSError(domain: "RPC", code: 5, userInfo: [NSLocalizedDescriptionKey: "JSON の文字列が不正です。"])
    }
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
      throw NSError(domain: "RPC", code: 6, userInfo: [NSLocalizedDescriptionKey: "metadata は JSON オブジェクトで指定してください。"])
    }
    guard let key = dictionary["key"] as? String, !key.isEmpty else {
      throw NSError(domain: "RPC", code: 7, userInfo: [NSLocalizedDescriptionKey: "key は文字列で指定してください。"])
    }
    guard let valueAny = dictionary["value"] else {
      throw NSError(domain: "RPC", code: 8, userInfo: [NSLocalizedDescriptionKey: "value を指定してください。"])
    }
    let valueJSON = AnyCodable(valueAny)
    return (key, valueAny, valueJSON)
  }

  private func handleDataChannelMessage(label: String, data: Data) {
    let text = String(data: data, encoding: .utf8) ?? data.map(\.description).joined(separator: ", ")

    if label == "push" {
      appendLog(direction: "recv", label: label, summary: "push", detail: text)
      return
    }
  }

  private func handleSignaling(_ signaling: Signaling) {
    guard case .offer(let offer) = signaling else {
      return
    }
    if let rpcMethods = offer.rpcMethods, !rpcMethods.isEmpty {
      DispatchQueue.main.async {
        self.rpcMethodsLabel.text = rpcMethods.joined(separator: ", ")
      }
    } else {
      DispatchQueue.main.async {
        self.rpcMethodsLabel.text = "未取得"
      }
    }

    if let simulcastRpcRids = offer.simulcastRpcRids, !simulcastRpcRids.isEmpty {
      let ridStrings = simulcastRpcRids.map { rid in
        switch rid {
        case .none:
          return "none"
        case .r0:
          return "r0"
        case .r1:
          return "r1"
        case .r2:
          return "r2"
        }
      }
      DispatchQueue.main.async {
        self.simulcastRpcRidsLabel.text = ridStrings.joined(separator: ", ")
      }
    } else {
      DispatchQueue.main.async {
        self.simulcastRpcRidsLabel.text = "未取得"
      }
    }
  }

  private func updateRPCMethods(using mediaChannel: MediaChannel) {
    let methods = mediaChannel.rpcMethods.map(\.displayName)
    DispatchQueue.main.async {
      self.rpcMethodsLabel.text = methods.isEmpty ? "未取得" : methods.joined(separator: ", ")
      let simulcastRids = mediaChannel.rpcSimulcastRids.map { rid in
        switch rid {
        case .none:
          return "none"
        case .r0:
          return "r0"
        case .r1:
          return "r1"
        case .r2:
          return "r2"
        }
      }
      self.simulcastRpcRidsLabel.text = simulcastRids.isEmpty ? "未取得" : simulcastRids.joined(separator: ", ")
    }
  }

  private func handleRPCResponse(response: RPCResponse<Any>, result: Any) {
    let detail = rpcResponseDetailText(result)
    appendLog(direction: "recv", label: "rpc", summary: "success", detail: detail)
  }

  private func handleRPCError(_ detail: RPCErrorDetail) {
    let info = rpcErrorDetailText(detail)
    appendLog(direction: "recv", label: "rpc", summary: "error(\(detail.code))", detail: info)
  }

  private func rpcResponseDetailText(_ result: Any) -> String {
    var lines: [String] = []
    lines.append("result: \(stringifyJSON(result))")
    return lines.isEmpty ? "response" : lines.joined(separator: "\n")
  }

  private func rpcErrorDetailText(_ detail: RPCErrorDetail) -> String {
    var lines: [String] = [
      "code: \(detail.code)",
      "message: \(detail.message)"
    ]
    if let data = detail.data {
      lines.append("data: \(stringifyJSON(data))")
    }
    return lines.joined(separator: "\n")
  }

  private func stringifyJSON(_ object: Any) -> String {
    guard JSONSerialization.isValidJSONObject(object),
      let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
      let text = String(data: data, encoding: .utf8)
    else {
      return String(describing: object)
    }
    return text
  }

  private func makeRequestDetail(method: String, params: [String: Any]) -> String {
    let payload: [String: Any] = [
      "jsonrpc": "2.0",
      "method": method,
      "params": params
    ]
    guard JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
      let text = String(data: data, encoding: .utf8)
    else {
      return String(describing: payload)
    }
    return text
  }

  private func appendLog(direction: String, label: String, summary: String, detail: String) {
    let item = RPCLogItem(
      timestamp: Date(),
      direction: direction,
      label: label,
      summary: summary,
      detail: detail
    )
    logs.append(item)
    DispatchQueue.main.async {
      self.historyTableView.reloadData()
      let lastRow = IndexPath(row: self.logs.count - 1, section: 0)
      self.historyTableView.scrollToRow(at: lastRow, at: .bottom, animated: true)
    }
  }

  private func presentAlert(title: String, message: String) {
    DispatchQueue.main.async {
      let alertController = UIAlertController(
        title: title,
        message: message,
        preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
      self.present(alertController, animated: true, completion: nil)
    }
  }

  private func handleDisconnect() {
    downstreamVideoView?.removeFromSuperview()
    downstreamVideoView = nil
    resolutionLabel.text = "Resolution: -"
    RPCSoraSDKManager.shared.disconnect()
    performSegue(withIdentifier: "Exit", sender: self)
  }

  private func handleUpdateStreams() {
    guard let mediaChannel = RPCSoraSDKManager.shared.currentMediaChannel else {
      return
    }

    let downstream = mediaChannel.receiverStreams.first

    if let downstream {
      if downstreamVideoView == nil {
        let videoView = ResolutionVideoView()
        videoView.onFrameSizeChanged = { [weak self] size in
          self?.resolutionLabel.text = "Resolution: \(Int(size.width))x\(Int(size.height))"
        }
        memberListView.addSubview(videoView)
        downstreamVideoView = videoView
      }
      memberListView.bringSubviewToFront(resolutionLabel)
      downstream.videoRenderer = downstreamVideoView
    } else {
      resolutionLabel.text = "Resolution: -"
      downstreamVideoView?.removeFromSuperview()
      downstreamVideoView = nil
    }

    layoutVideoView(for: memberListView.bounds.size)
  }

  private func layoutVideoView(for size: CGSize) {
    guard let videoView = downstreamVideoView else {
      return
    }
    videoView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
  }

  private func setupHeaderView() {
    connectedUrlLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    connectedUrlLabel.textColor = .secondaryLabel
    connectedUrlLabel.numberOfLines = 0
    connectedUrlLabel.text = "Connected URL: -"

    channelIdLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    channelIdLabel.textColor = .secondaryLabel
    channelIdLabel.numberOfLines = 1
    channelIdLabel.text = "Channel ID: -"

    methodButton.setTitle(selectedMethod.displayName, for: .normal)
    methodButton.contentHorizontalAlignment = .leading

    simulcastRidSegmentedControl.selectedSegmentIndex = 0

    senderConnectionIdTextField.borderStyle = .roundedRect
    senderConnectionIdTextField.placeholder = "sender_connection_id (optional)"

    pushSwitch.isOn = true

    metadataTextView.layer.borderColor = UIColor.separator.cgColor
    metadataTextView.layer.borderWidth = 1
    metadataTextView.layer.cornerRadius = 6
    metadataTextView.font = UIFont.preferredFont(forTextStyle: .body)
    metadataTextView.isScrollEnabled = false

    rpcMethodsLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    rpcMethodsLabel.numberOfLines = 0

    simulcastRpcRidsLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    simulcastRpcRidsLabel.numberOfLines = 0

    sendRequestButton.setTitle("Send Request", for: .normal)
    sendNotificationButton.setTitle("Send Notification", for: .normal)
    sendRequestButton.addTarget(self, action: #selector(onSendRequestButton(_:)), for: .touchUpInside)
    sendNotificationButton.addTarget(self, action: #selector(onSendNotificationButton(_:)), for: .touchUpInside)

    let header = UIView()
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 12
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false

    header.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
      stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),
    ])

    stack.addArrangedSubview(connectedUrlLabel)
    stack.addArrangedSubview(channelIdLabel)
    stack.addArrangedSubview(methodButton)

    let simulcastRow = labeledRow(title: "rid", control: simulcastRidSegmentedControl)
    simulcastRowView = simulcastRow
    stack.addArrangedSubview(simulcastRow)
    stack.addArrangedSubview(senderConnectionIdTextField)

    let pushRow = labeledRow(title: "push", control: pushSwitch)
    pushRowView = pushRow
    stack.addArrangedSubview(pushRow)
    stack.addArrangedSubview(metadataTextView)

    let sendButtonsRow = UIStackView(arrangedSubviews: [sendRequestButton, sendNotificationButton])
    sendButtonsRow.axis = .horizontal
    sendButtonsRow.spacing = 12
    sendButtonsRow.distribution = .fillEqually
    stack.addArrangedSubview(sendButtonsRow)

    stack.addArrangedSubview(labeledInfoRow(title: "rpc_methods", valueLabel: rpcMethodsLabel))
    stack.addArrangedSubview(labeledInfoRow(title: "simulcast_rpc_rids", valueLabel: simulcastRpcRidsLabel))

    headerView = header
    historyTableView.tableHeaderView = header

    metadataTextView.heightAnchor.constraint(equalToConstant: 120).isActive = true

    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onTapView(_:)))
    view.addGestureRecognizer(tapGestureRecognizer)
  }

  private func updateHeaderLayoutIfNeeded() {
    guard let headerView = headerView else { return }
    let targetSize = CGSize(width: historyTableView.bounds.width, height: 0)
    let size = headerView.systemLayoutSizeFitting(
      targetSize,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    if headerView.frame.size.height != size.height {
      headerView.frame.size.height = size.height
      historyTableView.tableHeaderView = headerView
    }
  }

  private func labeledRow(title: String, control: UIView) -> UIView {
    let label = UILabel()
    label.text = title
    label.setContentHuggingPriority(.required, for: .horizontal)

    let row = UIStackView(arrangedSubviews: [label, control])
    row.axis = .horizontal
    row.spacing = 12
    row.alignment = .center
    return row
  }

  private func labeledInfoRow(title: String, valueLabel: UILabel) -> UIView {
    let label = UILabel()
    label.text = title
    label.font = UIFont.preferredFont(forTextStyle: .footnote)
    label.textColor = .secondaryLabel
    label.setContentHuggingPriority(.required, for: .horizontal)

    let row = UIStackView(arrangedSubviews: [label, valueLabel])
    row.axis = .horizontal
    row.spacing = 12
    row.alignment = .top
    return row
  }
}

extension RPCRoomViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    logs.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "RPCLogCell", for: indexPath)
    let item = logs[indexPath.row]
    let time = timeFormatter.string(from: item.timestamp)
    cell.textLabel?.text = "\(time) [\(item.direction)] \(item.label) \(item.summary)"
    cell.detailTextLabel?.numberOfLines = 0
    cell.detailTextLabel?.text = item.detail
    cell.selectionStyle = .none
    return cell
  }
}
