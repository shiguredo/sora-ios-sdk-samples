import Sora
import UIKit

private let logger = SamplesLogger.tagged("RPCRoom")

// MARK: - RPC Error Definition

enum RPCError: LocalizedError {
  case invalidJsonString
  case metadataNotJsonObject
  case invalidJsonForItem
  case invalidMetadataKey
  case missingMetadataValue

  var errorDescription: String? {
    switch self {
    case .invalidJsonString:
      return "JSON の文字列が不正です。"
    case .metadataNotJsonObject:
      return "metadata は JSON オブジェクトで指定してください。"
    case .invalidJsonForItem:
      return "JSON の文字列が不正です。"
    case .invalidMetadataKey:
      return "key は文字列で指定してください。"
    case .missingMetadataValue:
      return "value を指定してください。"
    }
  }
}

private enum RPCMethod {
  case requestSimulcastRid
  case requestSpotlightRid
  case resetSpotlightRid
  case putSignalingNotifyMetadata
  case putSignalingNotifyMetadataItem

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

// MARK: - Video View helper

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
  private let metadataTextViewHeight: CGFloat = 120
  private var isAudioSoftMuted: Bool = false

  @IBOutlet weak var historyTableView: UITableView!
  @IBOutlet weak var memberListView: UIView!
  @IBOutlet weak var resolutionLabel: UILabel!
  @IBOutlet weak var micMuteButton: UIBarButtonItem?
  private let connectedUrlLabel = UILabel()
  private let channelIdLabel = UILabel()
  private let methodButton = UIButton(type: .system)
  private let simulcastRidSegmentedControl = UISegmentedControl(items: ["none", "r0", "r1", "r2"])
  private let spotlightFocusRidSegmentedControl = UISegmentedControl(items: [
    "none", "r0", "r1", "r2",
  ])
  private let spotlightUnfocusRidSegmentedControl = UISegmentedControl(items: [
    "none", "r0", "r1", "r2",
  ])
  private let senderConnectionIdTextField = UITextField()
  private let pushSwitch = UISwitch()
  private let metadataTextView = UITextView()
  private let metadataItemKeyTextField = UITextField()
  private let metadataItemValueTextView = UITextView()
  private let rpcMethodsLabel = UILabel()
  private let sendRequestButton = UIButton(type: .system)
  private let sendNotificationButton = UIButton(type: .system)
  private var headerView: UIView?
  private var simulcastRowView: UIView?
  private var spotlightFocusRowView: UIView?
  private var spotlightUnfocusRowView: UIView?
  private var pushRowView: UIView?
  private var metadataItemKeyRowView: UIView?
  private var metadataItemValueRowView: UIView?
  private var downstreamVideoView: ResolutionVideoView?

  private let metadataPresset = """
    {
      "example_key": "example_value"
    }
    """

  private let metadataItemValuePresset = """
    {"example":"value"}
    """

  private let availableMethods: [RPCMethod] = [
    .requestSimulcastRid,
    .requestSpotlightRid,
    .resetSpotlightRid,
    .putSignalingNotifyMetadata,
    .putSignalingNotifyMetadataItem,
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
    resolutionLabel.text = "Resolution: -"
    metadataTextView.text = ""
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

  @IBAction private func onMicMuteButton(_ sender: Any?) {
    guard let mediaChannel = RPCSoraSDKManager.shared.currentMediaChannel else {
      return
    }
    isAudioSoftMuted.toggle()
    mediaChannel.setAudioSoftMute(isAudioSoftMuted)
    updateMicButtonTitle()
  }

  @objc private func onTapView(_ sender: UITapGestureRecognizer) {
    senderConnectionIdTextField.endEditing(true)
    metadataTextView.endEditing(true)
  }

  private func setupMethodMenu() {
    let actions = availableMethods.map { method in
      UIAction(title: method.displayName, state: method == selectedMethod ? .on : .off) {
        [weak self] _ in
        self?.selectedMethod = method
        self?.updateMethodUI()
      }
    }
    methodButton.menu = UIMenu(title: "RPC Method", children: actions)
    methodButton.showsMenuAsPrimaryAction = true
  }

  private func updateMethodUI() {
    simulcastRowView?.isHidden =
      !(selectedMethod == .requestSimulcastRid)
    spotlightFocusRowView?.isHidden =
      !(selectedMethod == .requestSpotlightRid)
    spotlightUnfocusRowView?.isHidden =
      !(selectedMethod == .requestSpotlightRid)
    senderConnectionIdTextField.isHidden =
      !(selectedMethod == .requestSimulcastRid
      || selectedMethod == .requestSpotlightRid
      || selectedMethod == .resetSpotlightRid)
    pushRowView?.isHidden =
      !(selectedMethod == .putSignalingNotifyMetadata
      || selectedMethod == .putSignalingNotifyMetadataItem)
    metadataTextView.isHidden =
      !(selectedMethod == .putSignalingNotifyMetadata)
    metadataItemKeyRowView?.isHidden =
      !(selectedMethod == .putSignalingNotifyMetadataItem)
    metadataItemValueRowView?.isHidden =
      !(selectedMethod == .putSignalingNotifyMetadataItem)

    // PutSignalingNotifyMetadata 選択時はプリセット JSON を入力
    if selectedMethod == .putSignalingNotifyMetadata {
      metadataTextView.text = metadataPresset.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // PutSignalingNotifyMetadataItem 選択時は key フィールドをクリア、プリセット JSON を入力
    if selectedMethod == .putSignalingNotifyMetadataItem {
      metadataItemKeyTextField.text = ""
      metadataItemValueTextView.text = metadataItemValuePresset.trimmingCharacters(
        in: .whitespacesAndNewlines)
    }

    methodButton.setTitle(selectedMethod.displayName, for: .normal)
    setupMethodMenu()
  }

  private func updateMicButtonTitle() {
    micMuteButton?.title = isAudioSoftMuted ? "Mic Off" : "Mic"
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
          try await sendRPCAndLog(
            mediaChannel: mediaChannel,
            method: RequestSimulcastRid.self,
            params: params,
            methodName: RequestSimulcastRid.name,
            isNotification: isNotification
          )

        case .requestSpotlightRid:
          let params = RequestSpotlightRidParams(
            sendConnectionId: trimmedSenderConnectionId(),
            spotlightFocusRid: selectedSpotlightFocusRid(),
            spotlightUnfocusRid: selectedSpotlightUnfocusRid()
          )
          try await sendRPCAndLog(
            mediaChannel: mediaChannel,
            method: RequestSpotlightRid.self,
            params: params,
            methodName: RequestSpotlightRid.name,
            isNotification: isNotification
          )

        case .resetSpotlightRid:
          let params = ResetSpotlightRidParams(
            sendConnectionId: trimmedSenderConnectionId()
          )
          try await sendRPCAndLog(
            mediaChannel: mediaChannel,
            method: ResetSpotlightRid.self,
            params: params,
            methodName: ResetSpotlightRid.name,
            isNotification: isNotification
          )

        case .putSignalingNotifyMetadata:
          let metadataDict = try parseMetadata()
          let params = PutSignalingNotifyMetadataParams(
            metadata: metadataDict,
            push: pushSwitch.isOn ? true : nil
          )
          try await sendRPCAndLog(
            mediaChannel: mediaChannel,
            method: PutSignalingNotifyMetadata<[String: AnyCodable]>.self,
            params: params,
            methodName: PutSignalingNotifyMetadata<[String: AnyCodable]>.name,
            isNotification: isNotification
          )

        case .putSignalingNotifyMetadataItem:
          let (key, valueJSON) = try parseMetadataItem()
          let params = PutSignalingNotifyMetadataItemParams<AnyCodable>(
            key: key,
            value: valueJSON,
            push: pushSwitch.isOn ? true : nil
          )
          try await sendRPCAndLog(
            mediaChannel: mediaChannel,
            method: PutSignalingNotifyMetadataItem<AnyCodable, AnyCodable>.self,
            params: params,
            methodName: PutSignalingNotifyMetadataItem<AnyCodable, AnyCodable>.name,
            isNotification: isNotification
          )
        }
      } catch {
        logger.error("failed to send RPC: \(error)")
        presentAlert(title: "送信に失敗しました", message: error.localizedDescription)
      }
    }
  }

  private func sendRPCAndLog<Method: RPCMethodProtocol>(
    mediaChannel: MediaChannel,
    method: Method.Type,
    params: Method.Params,
    methodName: String,
    isNotification: Bool
  ) async throws {
    if isNotification {
      try await mediaChannel.rpc(
        method: method,
        params: params,
        isNotificationRequest: true
      )
    } else {
      let response = try await mediaChannel.rpc(
        method: method,
        params: params
      )
      if let response = response {
        appendLog(
          direction: "recv", label: "rpc", summary: "success",
          detail: stringifyJSON(response.result))
      }
    }

    appendLog(
      direction: isNotification ? "send(notification)" : "send",
      label: "rpc",
      summary: selectedMethod.displayName,
      detail: makeRequestDetail(
        method: methodName, params: paramsDictionary(from: params))
    )
  }

  private func selectedSimulcastRid() -> Rid {
    let index = simulcastRidSegmentedControl.selectedSegmentIndex
    let rids: [Rid] = [.none, .r0, .r1, .r2]
    return rids.indices.contains(index) ? rids[index] : .none
  }

  private func selectedSpotlightFocusRid() -> Rid {
    let index = spotlightFocusRidSegmentedControl.selectedSegmentIndex
    let rids: [Rid] = [.none, .r0, .r1, .r2]
    return rids.indices.contains(index) ? rids[index] : .none
  }

  private func selectedSpotlightUnfocusRid() -> Rid {
    let index = spotlightUnfocusRidSegmentedControl.selectedSegmentIndex
    let rids: [Rid] = [.none, .r0, .r1, .r2]
    return rids.indices.contains(index) ? rids[index] : .none
  }

  private func trimmedSenderConnectionId() -> String? {
    guard
      let text = senderConnectionIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
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
      let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      return dictionary
    }
    return [:]
  }

  private func parseMetadata() throws -> [String: AnyCodable] {
    let text = metadataTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty {
      return [:]
    }
    guard let data = text.data(using: .utf8) else {
      throw RPCError.invalidJsonString
    }
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
      throw RPCError.metadataNotJsonObject
    }
    return dictionary.mapValues(AnyCodable.init)
  }

  private func parseMetadataItem() throws -> (String, AnyCodable) {
    let key = metadataItemKeyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let valueText = metadataItemValueTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)

    if key.isEmpty {
      throw RPCError.invalidMetadataKey
    }
    if valueText.isEmpty {
      throw RPCError.missingMetadataValue
    }

    guard let data = valueText.data(using: .utf8) else {
      throw RPCError.invalidJsonForItem
    }

    let valueAny = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    let valueJSON = AnyCodable(valueAny)
    return (key, valueJSON)
  }

  private func handleDataChannelMessage(label: String, data: Data) {
    let text =
      String(data: data, encoding: .utf8) ?? data.map(\.description).joined(separator: ", ")

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
      "params": params,
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
    DispatchQueue.main.async {
      self.logs.append(item)
      let newIndexPath = IndexPath(row: self.logs.count - 1, section: 0)
      self.historyTableView.insertRows(at: [newIndexPath], with: .automatic)
      self.historyTableView.scrollToRow(at: newIndexPath, at: .bottom, animated: true)
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

    metadataItemKeyTextField.borderStyle = .roundedRect
    metadataItemKeyTextField.placeholder = "key"

    metadataItemValueTextView.layer.borderColor = UIColor.separator.cgColor
    metadataItemValueTextView.layer.borderWidth = 1
    metadataItemValueTextView.layer.cornerRadius = 6
    metadataItemValueTextView.font = UIFont.preferredFont(forTextStyle: .body)
    metadataItemValueTextView.isScrollEnabled = false

    rpcMethodsLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    rpcMethodsLabel.numberOfLines = 0

    sendRequestButton.setTitle("Send Request", for: .normal)
    sendNotificationButton.setTitle("Send Notification", for: .normal)
    sendRequestButton.addTarget(
      self, action: #selector(onSendRequestButton(_:)), for: .touchUpInside)
    sendNotificationButton.addTarget(
      self, action: #selector(onSendNotificationButton(_:)), for: .touchUpInside)

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

    let spotlightFocusRow = labeledRow(
      title: "focus_rid", control: spotlightFocusRidSegmentedControl)
    spotlightFocusRowView = spotlightFocusRow
    stack.addArrangedSubview(spotlightFocusRow)

    let spotlightUnfocusRow = labeledRow(
      title: "unfocus_rid", control: spotlightUnfocusRidSegmentedControl)
    spotlightUnfocusRowView = spotlightUnfocusRow
    stack.addArrangedSubview(spotlightUnfocusRow)

    stack.addArrangedSubview(senderConnectionIdTextField)

    let pushRow = labeledRow(title: "push", control: pushSwitch)
    pushRowView = pushRow
    stack.addArrangedSubview(pushRow)
    stack.addArrangedSubview(metadataTextView)

    let metadataItemKeyRow = labeledRow(title: "key", control: metadataItemKeyTextField)
    metadataItemKeyRowView = metadataItemKeyRow
    stack.addArrangedSubview(metadataItemKeyRow)

    let metadataItemValueLabel = UILabel()
    metadataItemValueLabel.text = "value"
    let metadataItemValueContainer = UIStackView(arrangedSubviews: [
      metadataItemValueLabel, metadataItemValueTextView,
    ])
    metadataItemValueContainer.axis = .vertical
    metadataItemValueContainer.spacing = 4
    metadataItemValueRowView = metadataItemValueContainer
    stack.addArrangedSubview(metadataItemValueContainer)

    let sendButtonsRow = UIStackView(arrangedSubviews: [sendRequestButton, sendNotificationButton])
    sendButtonsRow.axis = .horizontal
    sendButtonsRow.spacing = 12
    sendButtonsRow.distribution = .fillEqually
    stack.addArrangedSubview(sendButtonsRow)

    stack.addArrangedSubview(labeledInfoRow(title: "rpc_methods", valueLabel: rpcMethodsLabel))

    headerView = header
    historyTableView.tableHeaderView = header

    metadataTextView.heightAnchor.constraint(equalToConstant: metadataTextViewHeight).isActive =
      true

    metadataItemValueTextView.heightAnchor.constraint(equalToConstant: metadataTextViewHeight)
      .isActive =
      true

    let tapGestureRecognizer = UITapGestureRecognizer(
      target: self, action: #selector(onTapView(_:)))
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
