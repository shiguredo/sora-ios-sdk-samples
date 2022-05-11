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
    @State var channelId: String = "sora"
    @State var videoCodec: VideoCodec = .default
    @State var dataChannel: Availability = .unspecified
    @State var ignoreDisconnectWebSocket: Availability = .unspecified

    var body: some View {
        NavigationView {
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

                Section {
                    HStack {
                        Spacer()
                        Button("チャットに入室する", action: {
                            // TODO:
                        })
                        Spacer()
                    }
                }
            }
            .navigationTitle("ビデオチャット")
        }
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
