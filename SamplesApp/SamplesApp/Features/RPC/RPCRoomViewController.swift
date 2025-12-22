import Sora
import UIKit

private let logger = SamplesLogger.tagged("RPCRoom")

private struct RPCLogItem {
  let timestamp: Date
  let direction: String
  let label: String
  let summary: String
  let detail: String
}

private final class ResolutionVideoView: UIView, VideoRenderer {
  private let soraVideoView = VideoView()
  var onFrameSizeChanged: ((CGSize) -> Void)?

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
    onFrameSizeChanged?(size)
  }

  func render(videoFrame: VideoFrame?) {
    soraVideoView.render(videoFrame: videoFrame)
    if let videoFrame {
      onFrameSizeChanged?(CGSize(width: videoFrame.width, height: videoFrame.height))
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

private struct RequestSimulcastRidParams: Encodable {
  let rid: String
  let sender_connection_id: String?
}

private struct RequestSpotlightRidParams: Encodable {
  let send_connection_id: String?
  let spotlight_focus_rid: String
  let spotlight_unfocus_rid: String
}

private struct ResetSpotlightRidParams: Encodable {
  let send_connection_id: String?
}

private struct PutSignalingNotifyMetadataParams: Encodable {
  let metadata: [String: JSONValue]
  let push: Bool?
}

private struct PutSignalingNotifyMetadataItemParams: Encodable {
  let key: String
  let value: JSONValue
  let push: Bool?
}

private enum JSONValue: Encodable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  init?(any value: Any) {
    if let dictionary = value as? [String: Any] {
      var mapped: [String: JSONValue] = [:]
      for (key, item) in dictionary {
        guard let jsonValue = JSONValue(any: item) else {
          return nil
        }
        mapped[key] = jsonValue
      }
      self = .object(mapped)
      return
    }
    if let array = value as? [Any] {
      let mapped = array.compactMap { JSONValue(any: $0) }
      guard mapped.count == array.count else {
        return nil
      }
      self = .array(mapped)
      return
    }
    if let string = value as? String {
      self = .string(string)
      return
    }
    if let bool = value as? Bool {
      self = .bool(bool)
      return
    }
    if let number = value as? NSNumber {
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        self = .bool(number.boolValue)
      } else {
        self = .number(number.doubleValue)
      }
      return
    }
    if value is NSNull {
      self = .null
      return
    }
    return nil
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .object(let object):
      var container = encoder.container(keyedBy: DynamicCodingKeys.self)
      for (key, value) in object {
        try container.encode(value, forKey: DynamicCodingKeys(stringValue: key))
      }
    case .array(let array):
      var container = encoder.unkeyedContainer()
      for value in array {
        try container.encode(value)
      }
    case .string(let string):
      var container = encoder.singleValueContainer()
      try container.encode(string)
    case .number(let number):
      var container = encoder.singleValueContainer()
      try container.encode(number)
    case .bool(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }
}

private struct DynamicCodingKeys: CodingKey {
  let stringValue: String
  let intValue: Int? = nil

  init?(intValue: Int) {
    return nil
  }

  init(stringValue: String) {
    self.stringValue = stringValue
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

      mediaChannel.handlers.onReceiveRPCResponse = { [weak self] _, response in
        self?.handleRPCResponse(response)
      }

      mediaChannel.handlers.onReceiveRPCError = { [weak self] _, detail in
        self?.handleRPCError(detail)
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
      mediaChannel.handlers.onReceiveRPCResponse = nil
      mediaChannel.handlers.onReceiveRPCError = nil
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
      UIAction(title: method.rawValue, state: method == selectedMethod ? .on : .off) { [weak self] _ in
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
    methodButton.setTitle(selectedMethod.rawValue, for: .normal)
    setupMethodMenu()
  }

  private func sendRPC(isNotification: Bool) {
    guard let mediaChannel = RPCSoraSDKManager.shared.currentMediaChannel else {
      return
    }

    do {
      let expectsResponse = !isNotification
      let (params, logDetail) = try makeParams(for: selectedMethod)
      let sent = mediaChannel.callRPC(
        method: selectedMethod,
        params: params,
        expectsResponse: expectsResponse
      ) { [weak self] result in
        guard case .failure(let error) = result else {
          return
        }
        logger.error("cannot send RPC request: \(error)")
        self?.presentAlert(title: "送信に失敗しました", message: error.localizedDescription)
      }

      if !sent {
        return
      }

      appendLog(
        direction: isNotification ? "send(notification)" : "send",
        label: "rpc",
        summary: selectedMethod.rawValue,
        detail: logDetail
      )
    } catch {
      logger.error("failed to build RPC request: \(error)")
      presentAlert(title: "送信内容が不正です", message: error.localizedDescription)
    }
  }

  private func makeParams(for method: RPCMethod) throws -> (Encodable, String) {
    switch method {
    case .requestSimulcastRid:
      let params = RequestSimulcastRidParams(
        rid: selectedSimulcastRidString(),
        sender_connection_id: trimmedSenderConnectionId()
      )
      var logParams: [String: Any] = ["rid": selectedSimulcastRidString()]
      if let senderConnectionId = trimmedSenderConnectionId() {
        logParams["sender_connection_id"] = senderConnectionId
      }
      let detail = makeRequestDetail(method: method.rawValue, params: logParams)
      return (params, detail)
    case .requestSpotlightRid:
      let focusRid = selectedSimulcastRidString()
      let params = RequestSpotlightRidParams(
        send_connection_id: trimmedSenderConnectionId(),
        spotlight_focus_rid: focusRid,
        spotlight_unfocus_rid: "none"
      )
      var logParams: [String: Any] = [
        "spotlight_focus_rid": focusRid,
        "spotlight_unfocus_rid": "none"
      ]
      if let senderConnectionId = trimmedSenderConnectionId() {
        logParams["send_connection_id"] = senderConnectionId
      }
      let detail = makeRequestDetail(method: method.rawValue, params: logParams)
      return (params, detail)
    case .resetSpotlightRid:
      let params = ResetSpotlightRidParams(
        send_connection_id: trimmedSenderConnectionId()
      )
      var logParams: [String: Any] = [:]
      if let senderConnectionId = trimmedSenderConnectionId() {
        logParams["send_connection_id"] = senderConnectionId
      }
      let detail = makeRequestDetail(method: method.rawValue, params: logParams)
      return (params, detail)
    case .putSignalingNotifyMetadata:
      let (metadataAny, metadataJSON) = try parseMetadata()
      let params = PutSignalingNotifyMetadataParams(
        metadata: metadataJSON,
        push: pushSwitch.isOn ? true : nil
      )
      var logParams: [String: Any] = ["metadata": metadataAny]
      if pushSwitch.isOn {
        logParams["push"] = true
      }
      let detail = makeRequestDetail(method: method.rawValue, params: logParams)
      return (params, detail)
    case .putSignalingNotifyMetadataItem:
      let (key, valueAny, valueJSON) = try parseMetadataItem()
      let params = PutSignalingNotifyMetadataItemParams(
        key: key,
        value: valueJSON,
        push: pushSwitch.isOn ? true : nil
      )
      var logParams: [String: Any] = [
        "key": key,
        "value": valueAny
      ]
      if pushSwitch.isOn {
        logParams["push"] = true
      }
      let detail = makeRequestDetail(method: method.rawValue, params: logParams)
      return (params, detail)
    }
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

  private func parseMetadata() throws -> ([String: Any], [String: JSONValue]) {
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
    var mapped: [String: JSONValue] = [:]
    for (key, value) in dictionary {
      guard let jsonValue = JSONValue(any: value) else {
        throw NSError(domain: "RPC", code: 3, userInfo: [NSLocalizedDescriptionKey: "metadata に JSON にできない値が含まれています。"])
      }
      mapped[key] = jsonValue
    }
    return (dictionary, mapped)
  }

  private func parseMetadataItem() throws -> (String, Any, JSONValue) {
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
    guard let valueJSON = JSONValue(any: valueAny) else {
      throw NSError(domain: "RPC", code: 9, userInfo: [NSLocalizedDescriptionKey: "value が JSON に変換できません。"])
    }
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
      DispatchQueue.main.async {
        self.simulcastRpcRidsLabel.text = simulcastRpcRids.joined(separator: ", ")
      }
    } else {
      DispatchQueue.main.async {
        self.simulcastRpcRidsLabel.text = "未取得"
      }
    }
  }

  private func updateRPCMethods(using mediaChannel: MediaChannel) {
    let methods = mediaChannel.rpcMethods.map(\.rawValue)
    DispatchQueue.main.async {
      self.rpcMethodsLabel.text = methods.isEmpty ? "未取得" : methods.joined(separator: ", ")
      let simulcastRids = mediaChannel.rpcSimulcastRids
      self.simulcastRpcRidsLabel.text = simulcastRids.isEmpty ? "未取得" : simulcastRids.joined(separator: ", ")
    }
  }

  private func handleRPCResponse(_ response: RPCResponse) {
    if response.id == nil && response.result == nil {
      return
    }
    let detail = rpcResponseDetailText(response)
    appendLog(direction: "recv", label: "rpc", summary: "success", detail: detail)
  }

  private func handleRPCError(_ detail: RPCErrorDetail) {
    let info = rpcErrorDetailText(detail)
    appendLog(direction: "recv", label: "rpc", summary: "error(\(detail.code))", detail: info)
  }

  private func rpcResponseDetailText(_ response: RPCResponse) -> String {
    var lines: [String] = []
    if let id = response.id {
      lines.append("id: \(rpcIdText(id))")
    }
    if let result = response.result {
      lines.append("result: \(stringifyJSON(result))")
    }
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

  private func rpcIdText(_ id: RPCID) -> String {
    switch id {
    case .int(let value):
      return String(value)
    case .string(let value):
      return value
    }
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

    methodButton.setTitle(selectedMethod.rawValue, for: .normal)
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
    cell.detailTextLabel?.text = item.detail
    cell.detailTextLabel?.numberOfLines = 0
    cell.selectionStyle = .none
    return cell
  }
}
