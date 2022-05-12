import Sora
import SwiftUI

extension VideoCodec {
    var name: String {
        switch self {
        case .default:
            return "デフォルト"
        case .vp8:
            return "VP8"
        case .vp9:
            return "VP9"
        case .h264:
            return "H.264"
        case .av1:
            return "AV1"
        }
    }
}

enum Availability {
    case unspecified
    case disabled
    case enabled

    var name: String {
        switch self {
        case .unspecified:
            return "未指定"
        case .disabled:
            return "無効"
        case .enabled:
            return "有効"
        }
    }
}

struct ConfigurationView: View {
    @State private var channelId: String = AppEnvironment.channelId
    @State private var videoCodec: VideoCodec = .default
    @State private var dataChannel: Availability = .unspecified
    @State private var ignoreDisconnectWebSocket: Availability = .unspecified

    // 接続時のエラーです。
    @State private var connectionError: Error?

    // アラートを表示する必要がある場合に true にします。
    // エラーが発生したときに使います。
    @State private var showsAlert = false

    // 接続に成功したら true にします。
    // true にすると映像画面に遷移します。
    @State private var connectTag: Bool?

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section {
                        TextField("チャネルID", text: $channelId)
                    } header: {
                        Text("接続設定")
                    }

                    Section {
                        HStack {
                            Text("映像コーデック")
                            Spacer()
                            Menu(videoCodec.name) {
                                Button(VideoCodec.default.name) { videoCodec = .default }
                                Button(VideoCodec.vp8.name) { videoCodec = .vp8 }
                                Button(VideoCodec.vp9.name) { videoCodec = .vp9 }
                                Button(VideoCodec.h264.name) { videoCodec = .h264 }
                                Button(VideoCodec.av1.name) { videoCodec = .av1 }
                            }
                        }
                    } header: {
                        Text("配信設定")
                    }

                    Section {
                        AvailabilityMenu("データチャネル", value: $dataChannel)
                        AvailabilityMenu("WS切断を無視", value: $ignoreDisconnectWebSocket)
                    } header: {
                        Text("データチャネルシグナリング設定")
                    }

                    HStack {
                        Spacer()
                        // NavigationLink をボタンで操作します。
                        // このボタンをタップし、接続が確立できれば下記の NavigationLink が実行されます。
                        Button("チャットに入室する", action: {
                            SoraSDKManager.shared.connect(channelId: channelId,
                                                          role: .sendrecv,
                                                          multistreamEnabled: true)
                            { error in
                                // エラーがあればアラートを表示します。
                                if let error = error {
                                    self.connectionError = error
                                    self.showsAlert = true
                                    return
                                }

                                // 接続が確立したら NavigationLink を操作します。
                                connectTag = true
                            }
                        })
                        Spacer()
                    }
                }

                // 上記のボタンのタップ時、接続が確立できれば画面遷移します。
                NavigationLink(destination: VideoChatRoomView(),
                               tag: true, selection: $connectTag) {
                    EmptyView()
                }
            }
        }
        .navigationTitle("ビデオチャット")

        // 何らかのエラー時にアラートを表示します。
        .alert("エラー", isPresented: $showsAlert, actions: {
            Button("OK") {
                showsAlert = false
                connectionError = nil
            }
        }, message: {
            if let error = connectionError {
                Text(error.localizedDescription)
            } else {
                Text("エラー内容不明")
            }
        })
    }
}

struct AvailabilityMenu: View {
    var title: String
    var value: Binding<Availability>
    var `default`: Availability

    init(_ title: String, value: Binding<Availability>, default: Availability = .unspecified) {
        self.title = title
        self.value = value
        self.default = `default`
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Menu(`default`.name) {
                Button(Availability.unspecified.name) { value.wrappedValue = .unspecified }
                Button(Availability.disabled.name) { value.wrappedValue = .disabled }
                Button(Availability.enabled.name) { value.wrappedValue = .enabled }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationView()
    }
}
