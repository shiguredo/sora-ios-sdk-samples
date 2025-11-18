import Combine
import Foundation
import Sora

@MainActor
final class SwiftUIVideoChatViewModel: ObservableObject {
  enum ConnectionPhase {
    case idle
    case connecting
    case connected
  }

  @Published var channelId: String = SwiftUIVideoChatEnvironment.channelId
  @Published private(set) var connectionPhase: ConnectionPhase = .idle
  @Published private(set) var downstreamStreams: [MediaStream] = []
  @Published private(set) var upstreamStream: MediaStream?
  @Published var errorMessage: String?
  @Published private(set) var isMicMuted = false
  @Published private(set) var isCameraMuted = false

  private var mediaChannel: MediaChannel?
  private weak var observedUpstream: MediaStream?

  var isConnected: Bool { connectionPhase == .connected }
  var isConnecting: Bool { connectionPhase == .connecting }

  var canStartConnection: Bool {
    let trimmed = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty && !isConnecting && !isConnected
  }

  func connect() {
    guard canStartConnection else { return }
    connectionPhase = .connecting
    errorMessage = nil

    let trimmedChannelId = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
    var configuration = Configuration(
      urlCandidates: SwiftUIVideoChatEnvironment.urls,
      channelId: trimmedChannelId,
      role: .sendrecv
    )
    configuration.signalingConnectMetadata = SwiftUIVideoChatEnvironment.signalingConnectMetadata

    _ = Sora.shared.connect(configuration: configuration) { [weak self] mediaChannel, error in
      guard let self else { return }
      Task { @MainActor in
        if let error {
          self.connectionPhase = .idle
          self.errorMessage = error.localizedDescription
          return
        }

        guard let mediaChannel else {
          self.connectionPhase = .idle
          return
        }

        self.mediaChannel = mediaChannel
        self.installHandlers(for: mediaChannel)
        self.connectionPhase = .connected
        self.refreshStreams()
      }
    }
  }

  func disconnect() {
    mediaChannel?.disconnect(error: nil)
    cleanupAfterDisconnect()
  }

  func toggleMicMute() {
    guard let upstream = upstreamStream else { return }
    let nextMuted = !isMicMuted
    upstream.audioEnabled = !nextMuted
    isMicMuted = nextMuted
  }

  func toggleCameraMute() {
    guard let upstream = upstreamStream else { return }
    let nextMuted = !isCameraMuted
    upstream.videoEnabled = !nextMuted
    isCameraMuted = nextMuted
  }

  private func installHandlers(for mediaChannel: MediaChannel) {
    mediaChannel.handlers.onAddStream = { [weak self] _ in
      Task { @MainActor in
        self?.refreshStreams()
      }
    }

    mediaChannel.handlers.onRemoveStream = { [weak self] _ in
      Task { @MainActor in
        self?.refreshStreams()
      }
    }

    mediaChannel.handlers.onDisconnect = { [weak self] event in
      Task { @MainActor in
        if case .error(let error) = event {
          self?.errorMessage = error.localizedDescription
        }
        self?.cleanupAfterDisconnect()
      }
    }
  }

  private func refreshStreams() {
    guard let mediaChannel else {
      downstreamStreams = []
      upstreamStream = nil
      return
    }

    let upstream = mediaChannel.senderStream
    let downstreams = mediaChannel.receiverStreams

    downstreamStreams = downstreams
    upstreamStream = upstream

    observedUpstream?.handlers.onSwitchAudio = nil
    observedUpstream?.handlers.onSwitchVideo = nil
    observedUpstream = upstream

    upstream?.handlers.onSwitchAudio = { [weak self] isEnabled in
      Task { @MainActor in
        self?.isMicMuted = !isEnabled
      }
    }

    upstream?.handlers.onSwitchVideo = { [weak self] isEnabled in
      Task { @MainActor in
        self?.isCameraMuted = !isEnabled
      }
    }

    if let upstream {
      isMicMuted = !upstream.audioEnabled
      isCameraMuted = !upstream.videoEnabled
    } else {
      isMicMuted = false
      isCameraMuted = false
    }
  }

  private func cleanupAfterDisconnect() {
    mediaChannel?.handlers.onAddStream = nil
    mediaChannel?.handlers.onRemoveStream = nil
    mediaChannel?.handlers.onDisconnect = nil
    mediaChannel = nil

    observedUpstream?.handlers.onSwitchAudio = nil
    observedUpstream?.handlers.onSwitchVideo = nil
    observedUpstream = nil

    downstreamStreams = []
    upstreamStream = nil
    isMicMuted = false
    isCameraMuted = false
    connectionPhase = .idle
  }
}
