import Sora
import SwiftUI

struct SwiftUIVideoChatSampleView: View {
  @StateObject private var viewModel = SwiftUIVideoChatViewModel()

  var body: some View {
    navigationContainer
      .alert(
        "エラー",
        isPresented: Binding(
          get: { viewModel.errorMessage != nil },
          set: { isPresented in
            if !isPresented {
              viewModel.errorMessage = nil
            }
          }
        )
      ) {
        Button("OK", role: .cancel) {
          viewModel.errorMessage = nil
        }
      } message: {
        Text(viewModel.errorMessage ?? "")
      }
      .onDisappear {
        viewModel.disconnect()
      }
  }

  @ViewBuilder
  private var navigationContainer: some View {
    if #available(iOS 16.0, *) {
      NavigationStack {
        content
      }
    } else {
      NavigationView {
        content
      }
      .navigationViewStyle(StackNavigationViewStyle())
    }
  }

  @ViewBuilder
  private var content: some View {
    Group {
      if viewModel.isConnected {
        SwiftUIVideoChatRoomView(viewModel: viewModel)
      } else {
        SwiftUIVideoChatConfigView(viewModel: viewModel)
      }
    }
    .navigationTitle("SwiftUI Video Chat")
    .toolbar {
      if viewModel.isConnected {
        Button("切断") {
          viewModel.disconnect()
        }
      }
    }
  }
}

private struct SwiftUIVideoChatConfigView: View {
  @ObservedObject var viewModel: SwiftUIVideoChatViewModel

  var body: some View {
    Form {
      Section(header: Text("チャネル設定")) {
        TextField("チャネル ID", text: $viewModel.channelId)
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)
      }

      Section(footer: Text("SamplesApp/Configs/Environment.swift で接続先を設定できます。")) {
        Button {
          viewModel.connect()
        } label: {
          if viewModel.isConnecting {
            HStack {
              ProgressView()
              Text("接続中…")
            }
          } else {
            Text("接続")
          }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(!viewModel.canStartConnection)
      }
    }
  }
}

private struct SwiftUIVideoChatRoomView: View {
  @ObservedObject var viewModel: SwiftUIVideoChatViewModel

  private var gridColumns: [GridItem] {
    let count = max(
      1,
      min(3, Int(ceil(sqrt(Double(max(viewModel.downstreamStreams.count, 1))))))
    )
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
  }

  var body: some View {
    VStack(spacing: 16) {
      if viewModel.downstreamStreams.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "person.2")
            .font(.system(size: 32))
            .foregroundStyle(.secondary)
          Text("他の参加者を待機中です")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8]))
        )
      } else {
        ScrollView {
          LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(viewModel.downstreamStreams, id: \._objectIdentifier) { stream in
              SwiftUIVideoView(stream: stream, contentMode: .scaleAspectFill)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                  labelView(text: "Downstream")
                }
            }
          }
          .padding(.vertical, 4)
        }
      }

      if let upstream = viewModel.upstreamStream {
        SwiftUIVideoView(stream: upstream, contentMode: .scaleAspectFill)
          .frame(height: 180)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .overlay(alignment: .topLeading) {
            labelView(text: "自分の映像")
          }
          .shadow(radius: 6)
      } else {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
          .frame(height: 180)
          .overlay(alignment: .center) {
            Text("自分の映像を初期化中です…")
              .foregroundStyle(.secondary)
          }
      }

      controls
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(.systemBackground))
  }

  private var controls: some View {
    HStack(spacing: 16) {
      controlButton(
        systemName: viewModel.isMicMuted ? "mic.slash" : "mic",
        label: viewModel.isMicMuted ? "マイク再開" : "マイク停止"
      ) {
        viewModel.toggleMicMute()
      }

      controlButton(
        systemName: viewModel.isCameraMuted ? "video.slash" : "video",
        label: viewModel.isCameraMuted ? "カメラ再開" : "カメラ停止"
      ) {
        viewModel.toggleCameraMute()
      }

      Button(role: .destructive) {
        viewModel.disconnect()
      } label: {
        Label("切断", systemImage: "xmark")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
    }
  }

  private func controlButton(systemName: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(label, systemImage: systemName)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
  }

  private func labelView(text: String) -> some View {
    Text(text)
      .font(.caption2)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(.white)
      .background(.black.opacity(0.6), in: Capsule())
      .padding(8)
  }
}

extension MediaStream {
  fileprivate var _objectIdentifier: ObjectIdentifier {
    ObjectIdentifier(self)
  }
}
