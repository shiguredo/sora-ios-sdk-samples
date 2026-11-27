import AVFoundation
import CallKit
import Foundation
import Sora
import WebRTC

private let logger = SamplesLogger.tagged("CallKit")

/// CallKit の通話と Sora の接続をまとめて管理します。
///
/// CallKit の `CXProvider` は delegate を弱参照で保持するため、このクラスは
/// シングルトンとしてアプリの生存期間中保持します。画面を閉じても、通話の終了処理が
/// 完了するまではインスタンスが残ります。
///
/// CallKit が音声セッションを有効化する順序に合わせて、Sora の音声ユニットは
/// `Sora.usesManualAudio` で手動制御します。
@MainActor
final class CallKitCallManager: NSObject {
  /// 通話の状態です。
  enum CallState: Equatable {
    /// 通話していません。
    case idle
    /// CallKit に発信を要求中、または音声セッションの有効化を待っています。
    case requesting
    /// Sora に接続中です。
    case connecting
    /// 通話中です。
    case connected
  }

  /// 通話前の音声セッション設定です。通話終了後に元へ戻すために使います。
  private struct AudioSessionSnapshot {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
  }

  static let shared = CallKitCallManager()

  /// 現在の通話状態です。
  private(set) var state: CallState = .idle

  /// 画面に表示する状態の説明です。
  private(set) var statusMessage = "待機中"

  /// 状態が変わったときに呼ばれます。
  var onStateChanged: ((CallState, String) -> Void)?

  /// 発信を開始できる状態かどうかです。
  var canStartCall: Bool {
    state == .idle
      && currentCallUUID == nil
      && !isPermissionRequestActive
      && !isEndingCall
      && !isAudioSessionActive
  }

  /// CallKit で通話を終了できる状態かどうかです。
  var canEndCall: Bool {
    currentCallUUID != nil && state != .idle && !isEndingCall
  }

  /// CallKit が音声セッションを有効化しているかどうかです。
  ///
  /// 通話終了直後は state が idle でも deactivate が完了していないことがあるため、
  /// 新しい通話の開始条件に使います。
  var isAudioSessionActive: Bool {
    didActivateAudioSession
  }

  // SoraSDKManager や他のサンプルと接続結果を取り違えないように、このサンプル専用の
  // Sora インスタンスを使います。音声セッションは全インスタンスで共有されるため、
  // AudioUnit プロファイルの競合は SDK の AudioSessionCoordinator が検出します。
  private let sora = Sora()
  private let provider: CXProvider
  private let callController = CXCallController()

  /// 現在の通話の UUID です。
  private var currentCallUUID: UUID?

  /// 通話終了を CallKit に要求済みかどうかです。
  private var isEndingCall = false

  /// 発信先として指定されたチャネル ID です。
  private var channelId = ""

  /// 接続済みの Sora の MediaChannel です。
  private var mediaChannel: MediaChannel?

  /// 接続試行中のタスクです。
  private var connectionTask: ConnectionTask?

  /// Sora のイベント購読タスクです。
  private var eventTask: Task<Void, Never>?

  /// 接続済みの Sora の接続 ID です。
  private var activeConnectionId: String?

  /// CallKit の start action を実行済みかどうかです。
  private var didPerformStartAction = false

  /// 通話が保留中かどうかです。
  private var isHeld = false

  /// 音声ユニットが利用可能になる前に要求されたミュート状態です。
  private var pendingMute: Bool?

  /// CallKit が音声セッションを有効化したかどうかです。
  private var didActivateAudioSession = false

  /// 通話前の音声セッション設定です。
  private var audioSessionSnapshot: AudioSessionSnapshot?

  /// didActivate が来ない場合に通話を終了させるための watchdog です。
  private var activationTimeoutTask: Task<Void, Never>?

  /// didDeactivate が来ない場合に音声セッションを復旧するための watchdog です。
  private var deactivateTimeoutTask: Task<Void, Never>?

  /// CXEndCallAction が実行されない場合に通話を終了させるための watchdog です。
  private var endCallTimeoutTask: Task<Void, Never>?

  /// マイクの使用許可を確認中かどうかです。
  private var isPermissionRequestActive = false

  private override init() {
    let configuration = CXProviderConfiguration()
    configuration.supportsVideo = false
    configuration.maximumCallGroups = 1
    configuration.maximumCallsPerCallGroup = 1
    configuration.supportedHandleTypes = [.generic]
    configuration.includesCallsInRecents = false
    provider = CXProvider(configuration: configuration)

    super.init()

    provider.setDelegate(self, queue: .main)
  }

  // MARK: - 発信

  /// 指定したチャネルへ発信します。
  ///
  /// - parameter channelId: 接続するチャネル ID
  func startCall(channelId: String) {
    guard canStartCall else {
      return
    }

    let trimmedChannelId = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedChannelId.isEmpty else {
      update(state: .idle, message: "チャネル ID を入力してください")
      return
    }
    guard sora.mediaChannels.isEmpty, Sora.shared.mediaChannels.isEmpty else {
      update(
        state: .idle,
        message: "他の接続が残っています。接続が完全に切断されてから再度発信してください")
      return
    }

    switch microphonePermission() {
    case .granted:
      beginCall(channelId: trimmedChannelId)
    case .denied:
      update(
        state: .idle,
        message: "マイクの使用が許可されていません。設定アプリで許可してください")
    case .undetermined:
      isPermissionRequestActive = true
      update(state: .requesting, message: "マイクの使用許可を確認しています")
      requestMicrophonePermission { [weak self] granted in
        Task { @MainActor [weak self] in
          guard let self, self.isPermissionRequestActive else {
            return
          }
          self.isPermissionRequestActive = false
          guard granted else {
            self.update(
              state: .idle,
              message: "マイクの使用が許可されていません。設定アプリで許可してください")
            return
          }
          self.beginCall(channelId: trimmedChannelId)
        }
      }
    @unknown default:
      update(state: .idle, message: "マイクの使用許可の状態を取得できませんでした")
    }
  }

  /// CallKit に発信を要求します。
  private func beginCall(channelId: String) {
    guard currentCallUUID == nil,
      state == .idle || state == .requesting,
      !didActivateAudioSession,
      !isEndingCall
    else {
      return
    }

    self.channelId = channelId
    currentCallUUID = UUID()
    isEndingCall = false
    isHeld = false
    pendingMute = nil
    didPerformStartAction = false

    // CallKit が音声セッションを有効化するまでは、Sora の音声ユニットを起動しない。
    sora.usesManualAudio = true
    sora.audioEnabled = false

    update(state: .requesting, message: "発信しています")

    guard let callUUID = currentCallUUID else {
      return
    }
    let handle = CXHandle(type: .generic, value: channelId)
    let startCallAction = CXStartCallAction(call: callUUID, handle: handle)
    startCallAction.isVideo = false
    let transaction = CXTransaction(action: startCallAction)

    // CXStartCallAction が実行されない場合にも備え、要求時点から watchdog を開始する。
    startActivationWatchdog()

    callController.request(transaction) { [weak self] error in
      // Error は Sendable ではないため、Task へ渡す前に文字列へ変換する。
      let errorMessage = error?.localizedDescription
      Task { @MainActor [weak self] in
        guard let self, self.currentCallUUID == callUUID else {
          return
        }
        if let errorMessage {
          logger.error("[sample] CXStartCallAction request failed: \(errorMessage)")
          self.resetCall(message: "発信に失敗しました: \(errorMessage)")
        } else {
          logger.info("[sample] CXStartCallAction requested. uuid=\(callUUID.uuidString)")
        }
      }
    }
  }

  /// 画面から通話を終了します。
  ///
  /// CallKit の通話 UI と状態を揃えるため、Sora を直接切断せずに `CXEndCallAction` を要求します。
  func endCall() {
    guard let callUUID = currentCallUUID,
      state == .requesting || state == .connecting || state == .connected,
      !isEndingCall
    else {
      return
    }

    isEndingCall = true
    update(state: state, message: "通話を終了しています")
    startEndCallWatchdog()

    let endCallAction = CXEndCallAction(call: callUUID)
    callController.request(CXTransaction(action: endCallAction)) { [weak self] error in
      let errorMessage = error?.localizedDescription
      Task { @MainActor [weak self] in
        guard let self, self.currentCallUUID == callUUID, let errorMessage else {
          return
        }
        logger.error("[sample] CXEndCallAction request failed: \(errorMessage)")
        self.finishCall(
          message: "通話の終了要求に失敗しました。通話を終了します: \(errorMessage)",
          reason: .failed)
      }
    }
  }

  /// サンプル画面を閉じるときに、通話中なら終了します。
  func endCallIfNeeded() {
    // 画面を閉じた後に、許可待ちのコールバックから通話が始まらないようにする。
    isPermissionRequestActive = false

    guard state != .idle else {
      return
    }
    guard currentCallUUID != nil else {
      resetCall(message: "待機中")
      return
    }
    endCall()
  }

  // MARK: - Sora への接続

  /// Sora への接続を開始します。
  private func connectSora() {
    update(state: .connecting, message: "Sora に接続しています")

    // 接続結果は購読 API の connected / connectFailed で受けるため、接続を開始する前に
    // 購読を開始する (購読を開始する前に配送されたイベントは届かない)。
    let events = sora.subscribeEvents()
    eventTask?.cancel()
    eventTask = Task { [weak self] in
      for await event in events {
        guard let self else {
          return
        }
        self.handle(event: event)
      }
    }

    let configuration = CallKitEnvironment.makeConfiguration(channelId: channelId)
    // 接続の結果は購読 API で受けるため、handler では何もしない。
    connectionTask = sora.connect(configuration: configuration) { @Sendable _, _ in }
  }

  /// Sora のイベントを処理します。
  private func handle(event: SoraEvent) {
    switch event.kind {
    case .connected:
      handleConnected(event)
    case .connectFailed:
      guard state == .connecting, !isEndingCall else {
        return
      }
      let message = event.error?.message ?? "接続に失敗しました"
      logger.error("[sample] Sora connect failed: \(message)")
      finishCall(message: "接続に失敗しました: \(message)", reason: .failed)
    case .disconnected:
      // 終了要求済みなら、切断の処理は end action / watchdog に任せる。
      // ここで finishCall すると、保留中の CXEndCallAction と二重に終了報告する。
      if isEndingCall {
        return
      }
      // 接続完了前は接続 ID がまだ確定していないため、接続中の切断もこの通話として扱う。
      if let activeConnectionId {
        guard event.connectionId == activeConnectionId else {
          return
        }
      } else {
        guard state == .connecting else {
          return
        }
      }
      let reason: CXCallEndedReason = event.error == nil ? .remoteEnded : .failed
      logger.info("[sample] Sora disconnected. connectionId=\(event.connectionId ?? "-")")
      finishCall(message: "通話が終了しました", reason: reason)
    default:
      break
    }
  }

  /// Sora の接続完了を処理します。
  private func handleConnected(_ event: SoraEvent) {
    guard let connectionId = event.connectionId,
      let mediaChannel = sora.mediaChannels.first(where: { $0.connectionId == connectionId })
    else {
      logger.error(
        "[sample] connected event has no media channel. connectionId=\(event.connectionId ?? "-")"
      )
      if state == .connecting {
        finishCall(
          message: "接続後の MediaChannel を取得できませんでした",
          reason: .failed)
      }
      return
    }

    // 接続完了と通話終了が競合した場合、この接続はもう所有していない。
    // 切断しないと MediaChannel が残り、次回の発信ができなくなる。
    guard state == .connecting, let callUUID = currentCallUUID, !isEndingCall else {
      logger.info(
        "[sample] connected event after call ended. disconnect. connectionId=\(connectionId)")
      mediaChannel.disconnect(error: nil)
      return
    }

    self.mediaChannel = mediaChannel
    activeConnectionId = connectionId
    connectionTask = nil
    logger.info("[sample] Sora connected. connectionId=\(connectionId)")

    // 接続完了後に音声モードを設定する。CallKit が有効化した音声セッションを
    // そのまま利用するため、ここでは音声セッションの activate は行わない。
    switch sora.setAudioMode(
      .voiceChat(output: .default),
      options: [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay]
    ) {
    case .success:
      provider.reportOutgoingCall(with: callUUID, connectedAt: Date())
      update(state: .connected, message: isHeld ? "保留中" : "通話中")
      // 接続前にミュートが要求されていた場合は、音声ユニットが使えるようになったここで適用する。
      if let pendingMute {
        self.pendingMute = nil
        if let error = mediaChannel.setAudioHardMute(pendingMute) {
          logger.error("[sample] setAudioHardMute failed: \(error)")
        }
      }
    case .failure(let error):
      logger.error("[sample] setAudioMode failed: \(error)")
      finishCall(
        message: "音声モードの設定に失敗しました: \(error.localizedDescription)",
        reason: .failed)
    }
  }

  /// 音声セッションの有効化が一定時間来ない場合に通話を終了させる watchdog を開始します。
  private func startActivationWatchdog() {
    guard !didActivateAudioSession else {
      return
    }
    activationTimeoutTask?.cancel()
    activationTimeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 10_000_000_000)
      guard !Task.isCancelled else {
        return
      }
      self?.handleActivationTimeout()
    }
  }

  /// 音声セッションの有効化待ちがタイムアウトしたときの処理です。
  private func handleActivationTimeout() {
    guard state == .requesting, currentCallUUID != nil else {
      return
    }
    logger.error("[sample] audio session activation timed out")
    finishCall(message: "音声セッションの有効化がタイムアウトしました", reason: .failed)
  }

  /// didDeactivate が来ない場合に備え、音声セッションの復旧を予約します。
  private func startDeactivateWatchdog() {
    guard didActivateAudioSession else {
      return
    }
    deactivateTimeoutTask?.cancel()
    deactivateTimeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      guard !Task.isCancelled else {
        return
      }
      self?.handleDeactivateTimeout()
    }
  }

  /// didDeactivate が来ないまま一定時間が経過したときの処理です。
  private func handleDeactivateTimeout() {
    guard state == .idle, didActivateAudioSession else {
      return
    }
    logger.warning("[sample] audio session deactivation timed out")
    RTCAudioSession.sharedInstance().audioSessionDidDeactivate(AVAudioSession.sharedInstance())
    didActivateAudioSession = false
    sora.audioEnabled = false
    sora.usesManualAudio = false
    restoreAudioMode()
    onStateChanged?(state, statusMessage)
  }

  /// CXEndCallAction が実行されない場合に備え、通話終了の watchdog を開始します。
  private func startEndCallWatchdog() {
    endCallTimeoutTask?.cancel()
    endCallTimeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      guard !Task.isCancelled else {
        return
      }
      self?.handleEndCallTimeout()
    }
  }

  /// CXEndCallAction が実行されないまま一定時間が経過したときの処理です。
  private func handleEndCallTimeout() {
    guard state != .idle, isEndingCall else {
      return
    }
    logger.error("[sample] CXEndCallAction timed out")
    finishCall(message: "通話の終了処理がタイムアウトしました", reason: .failed)
  }

  /// Sora の接続を切断します。
  private func cleanupSoraConnection() {
    eventTask?.cancel()
    eventTask = nil

    connectionTask?.cancel()
    connectionTask = nil

    // 接続完了イベントと終了処理が競合して mediaChannel を取得できなかった場合に備え、
    // このサンプル専用の Sora に残った接続もすべて切断する。
    for channel in sora.mediaChannels {
      channel.disconnect(error: nil)
    }
    mediaChannel = nil
  }

  /// CallKit の通話 UI に、このサンプルが扱う操作を伝えます。
  private func reportCallUpdate(for callUUID: UUID, handle: CXHandle) {
    let update = CXCallUpdate()
    update.remoteHandle = handle
    update.hasVideo = false
    update.supportsDTMF = false
    update.supportsHolding = true
    update.supportsGrouping = false
    update.supportsUngrouping = false
    provider.reportCall(with: callUUID, updated: update)
  }

  // MARK: - 状態の更新

  /// 通話を終了し、状態を待機中に戻します。
  private func finishCall(message: String, reason: CXCallEndedReason) {
    guard let callUUID = currentCallUUID else {
      resetCall(message: message)
      return
    }

    if didPerformStartAction {
      provider.reportCall(with: callUUID, endedAt: Date(), reason: reason)
    } else {
      logger.warning("[sample] skip reportCall for call that never started")
    }
    resetCall(message: message)
  }

  /// 通話に関する状態と音声セッションの設定を破棄します。
  private func resetCall(message: String) {
    activationTimeoutTask?.cancel()
    activationTimeoutTask = nil
    deactivateTimeoutTask?.cancel()
    deactivateTimeoutTask = nil
    endCallTimeoutTask?.cancel()
    endCallTimeoutTask = nil
    cleanupSoraConnection()

    currentCallUUID = nil
    activeConnectionId = nil
    channelId = ""
    didPerformStartAction = false
    isEndingCall = false
    isHeld = false
    pendingMute = nil
    isPermissionRequestActive = false

    // CallKit が activate した音声セッションは didDeactivate で後始末する。
    // activate 前に失敗した場合は、ここで手動制御を解除して元の音声モードへ戻す。
    sora.audioEnabled = false
    if didActivateAudioSession {
      // didDeactivate が来ない場合に備え、一定時間後に音声セッションを復旧する。
      startDeactivateWatchdog()
    } else {
      sora.usesManualAudio = false
      restoreAudioMode()
    }

    update(state: .idle, message: message)
  }

  /// 通話前の音声セッション設定へ戻します。
  ///
  /// CallKit の音声セッションが有効な間は呼び出しません。
  private func restoreAudioMode() {
    guard let snapshot = audioSessionSnapshot else {
      return
    }

    var restoreError: Error?
    sora.configureAudioSession {
      do {
        let session = RTCAudioSession.sharedInstance()
        try session.setCategory(snapshot.category, with: snapshot.options)
        try session.setMode(snapshot.mode)
      } catch {
        restoreError = error
      }
    }
    if let restoreError {
      logger.warning("[sample] failed to restore audio session: \(restoreError)")
      return
    }
    audioSessionSnapshot = nil
  }

  /// 状態と画面へ表示するメッセージを更新します。
  private func update(state: CallState, message: String) {
    self.state = state
    statusMessage = message
    logger.info("[sample] state=\(state), message=\(message)")
    onStateChanged?(state, message)
  }

  // MARK: - 音声セッション

  /// CallKit に音声セッションを管理させるため、カテゴリとモードだけを設定します。
  ///
  /// この時点では音声セッションを activate しません。CallKit が通話の優先度を上げて
  /// activate した後に `provider(_:didActivate:)` が呼ばれます。
  private func configureAudioSessionForCall() throws {
    var configurationError: Error?
    sora.configureAudioSession {
      do {
        let session = RTCAudioSession.sharedInstance()
        if audioSessionSnapshot == nil {
          audioSessionSnapshot = AudioSessionSnapshot(
            category: AVAudioSession.Category(rawValue: session.category),
            mode: AVAudioSession.Mode(rawValue: session.mode),
            options: session.categoryOptions)
        }
        try session.setCategory(
          .playAndRecord,
          with: [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay])
        try session.setMode(.voiceChat)
      } catch {
        configurationError = error
      }
    }
    if let configurationError {
      throw configurationError
    }
  }

  /// マイクの使用許可を取得します。
  private func requestMicrophonePermission(completion: @escaping @Sendable (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission(completionHandler: completion)
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission(completion)
    }
  }

  /// 現在のマイクの使用許可の状態を返します。
  private func microphonePermission() -> AVAudioSession.RecordPermission {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted:
        return .granted
      case .denied:
        return .denied
      case .undetermined:
        return .undetermined
      @unknown default:
        return .undetermined
      }
    }
    return AVAudioSession.sharedInstance().recordPermission
  }
}

// MARK: - CXProviderDelegate

extension CallKitCallManager: CXProviderDelegate {
  func providerDidReset(_ provider: CXProvider) {
    logger.warning("[sample] CXProvider did reset")
    // reset 時は didDeactivate が来ない可能性があるため、activate 済みなら対応を取る。
    if didActivateAudioSession {
      RTCAudioSession.sharedInstance().audioSessionDidDeactivate(AVAudioSession.sharedInstance())
      didActivateAudioSession = false
    }
    resetCall(message: "システムにより通話がリセットされました")
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    guard action.callUUID == currentCallUUID else {
      action.fail()
      return
    }
    guard state == .requesting, !isEndingCall else {
      // 終了要求後の start action は実行しない。end action が来ない場合は
      // endCall が開始した watchdog が通話を終了させる。
      action.fail()
      return
    }

    do {
      try configureAudioSessionForCall()
    } catch {
      logger.error("[sample] failed to configure audio session: \(error)")
      action.fail()
      resetCall(message: "音声セッションの設定に失敗しました: \(error.localizedDescription)")
      return
    }

    didPerformStartAction = true
    provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
    action.fulfill()
    reportCallUpdate(for: action.callUUID, handle: action.handle)
    update(state: .requesting, message: "音声セッションの有効化を待っています")
    logger.info("[sample] CXStartCallAction performed. uuid=\(action.callUUID.uuidString)")
  }

  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    guard action.callUUID == currentCallUUID else {
      action.fail()
      return
    }
    guard let mediaChannel else {
      // 接続前のミュート要求は、接続後に適用する。
      if state == .requesting || state == .connecting {
        pendingMute = action.isMuted
        action.fulfill()
        return
      }
      action.fail()
      return
    }
    pendingMute = nil
    if let error = mediaChannel.setAudioHardMute(action.isMuted) {
      logger.error("[sample] setAudioHardMute failed: \(error)")
      action.fail()
      return
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    guard action.callUUID == currentCallUUID,
      state == .requesting || state == .connecting || state == .connected
    else {
      action.fail()
      return
    }
    isHeld = action.isOnHold
    // 保留中は音声ユニットを止め、Sora の接続は維持する。
    // 保留解除では CallKit が音声セッションを activate して didActivate を呼ぶため、
    // ここで audioEnabled を true にしない (activate 前に音声ユニットを起動しない)。
    if action.isOnHold {
      sora.audioEnabled = false
    } else if didActivateAudioSession {
      // CallKit が音声セッションを deactivate していない保留解除の場合だけ起動する。
      sora.audioEnabled = !isHeld
    }
    if state == .connected {
      update(state: .connected, message: action.isOnHold ? "保留中" : "通話中")
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard action.callUUID == currentCallUUID else {
      // 既に終了処理が完了している場合も、アクション自体は完了させる。
      action.fulfill()
      return
    }

    action.fulfill()
    resetCall(message: "通話を終了しました")
    logger.info("[sample] CXEndCallAction performed. uuid=\(action.callUUID.uuidString)")
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    activationTimeoutTask?.cancel()
    activationTimeoutTask = nil

    // CallKit がアプリの外で音声セッションを activate したことを WebRTC に伝える。
    // これを忘れると RTCAudioSession の active 状態が実際の状態とずれ、音声が起動しない。
    if !didActivateAudioSession {
      RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
      didActivateAudioSession = true
      // 画面の発信ボタンの有効状態を更新する。
      onStateChanged?(state, statusMessage)
    }

    guard currentCallUUID != nil, state != .idle, !isEndingCall else {
      // 通話終了後に遅れて activate が届いた場合も、deactivate が来なければ
      // 音声セッションが残るため、復旧用の watchdog を開始する。
      if state == .idle {
        startDeactivateWatchdog()
      }
      return
    }

    // CallKit が音声セッションを有効化したので、Sora の音声ユニットを起動できる。
    sora.audioEnabled = !isHeld

    // connectSora() は state を .connecting に変えるため、初回の didActivate だけで接続する。
    if state == .requesting {
      connectSora()
    }
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    activationTimeoutTask?.cancel()
    activationTimeoutTask = nil
    deactivateTimeoutTask?.cancel()
    deactivateTimeoutTask = nil

    // CallKit が音声セッションを deactivate したことを WebRTC に伝える。
    // 対応する activate を通知していない場合は通知しない。
    if didActivateAudioSession {
      RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
      didActivateAudioSession = false
    }

    sora.audioEnabled = false
    if state == .idle {
      // 通話が終了していれば、他のサンプルのために手動制御を解除して音声モードを戻す。
      sora.usesManualAudio = false
      restoreAudioMode()
    }

    // 音声セッションの deactivate が完了したので、発信ボタンの有効状態を更新する。
    onStateChanged?(state, statusMessage)
  }

  func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
    logger.error("[sample] CXProvider action timed out: \(type(of: action))")

    // 古い通話のアクションが新しい通話を終了させないように、通話 UUID を照合する。
    if let callAction = action as? CXCallAction, callAction.callUUID != currentCallUUID {
      logger.warning("[sample] ignore timeout from old call: \(callAction.callUUID.uuidString)")
      return
    }

    // 発信・終了のタイムアウトは通話自体を終了させる。ミュートや保留のタイムアウトでは
    // 通話は継続しているため、Sora の接続を破棄しない。
    if action is CXStartCallAction || action is CXEndCallAction {
      finishCall(message: "CallKit の通話操作がタイムアウトしました", reason: .failed)
      return
    }
    logger.warning("[sample] call continues after action timeout: \(type(of: action))")
  }
}
