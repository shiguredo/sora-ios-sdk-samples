import SwiftUI
import Sora

struct ContentView: View {
    @State private var mediaChannel: MediaChannel?

    @State private var senderStream: MediaStream?
    // アラートを表示するための状態管理変数
    @State private var showsAlert = false
    // 接続時のエラー
    @State private var connectionError: Error?
    // 接続状態
    private var isConnected: Bool {
        mediaChannel?.isAvailable ?? false
    }

    var body: some View {
        VStack {
            ZStack {
                Video(senderStream)
                    .videoAspect(.fill)
                    .ignoresSafeArea()
                // この中の要素は画面下に寄せる
                VStack {
                    Spacer()
                    HStack {
                        Button {
                            connect()
                        } label: {
                            Text("接続")
                                .font(.title)
                        }.disabled(isConnected)
                        Button {
                            disconnect()
                        } label: {
                            Text("切断")
                                .font(.title)
                        }.disabled(!isConnected)
                    }
                }.padding()

            }
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

    func connect() {
        if isConnected {
            print("Already connected.")
            return
        }

        var config = Configuration(
            urlCandidates: AppEnvironment.urls,
            channelId: AppEnvironment.channelId,
            role: .sendonly,
            multistreamEnabled: true)
        config.signalingConnectMetadata = AppEnvironment.signalingConnectMetadata

        // mediaChannel のイベントハンドラ
        config.mediaChannelHandlers.onConnect = { error in
            if error != nil {
                self.connectionError = error
                self.showsAlert = true
                print("Error: \(error!)")
            }
            // 接続に成功した場合、senderStream がセットされているので senderStream にセットする
            self.senderStream = self.mediaChannel?.senderStream
        }

        // Soraに接続を試みます。
        _ = Sora.shared.connect(configuration: config) { mediaChannel, error in
            // 接続に成功した場合は、mediaChannelに値が返され、errorがnilになります。
            // 一方、接続に失敗した場合は、mediaChannelはnilとなり、errorが返されます。
            if let error = error {
                connectionError = error
                showsAlert = true
                print("Error: \(error)")
            }
            self.mediaChannel = mediaChannel
        }
    }

    func disconnect() {
        if isConnected == false {
            print("Already disconnected.")
            return
        }
        guard let mediaChannel = self.mediaChannel else {
            return
        }
        mediaChannel.disconnect(error: nil)
        self.mediaChannel = nil
        self.senderStream = nil
    }
}

#Preview {
    ContentView()
}
