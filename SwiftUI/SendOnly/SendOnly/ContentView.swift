import SwiftUI
import Sora

struct ContentView: View {
    @State private var senderStream: MediaStream?
    // アラートを表示するための状態管理変数
    @State private var showsAlert = false
    // 接続時のエラー
    @State private var connectionError: Error?

    var mediaChannel: MediaChannel? {
        SoraSDKManager.shared.currentMediaChannel
    }

    var body: some View {
        VStack {
            ZStack {
                Video(senderStream)
                    .videoAspect(.fill)
                // この中の要素は画面下に寄せる
                VStack {
                    Spacer()
                    HStack {
                        Button {
                            connect()
                        } label: {
                            Text("接続")
                                .font(.title)
                        }
                        Button {
                            disconnect()
                        } label: {
                            Text("切断")
                                .font(.title)
                        }
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
        
        // Sora 接続処理
        SoraSDKManager.shared.connect(config: config) { error in
            if let error {
                self.connectionError = error
                self.showsAlert = true
                print("Error: \(error)")
            } else {
                print("Connected")
            }
        }
    }

    func disconnect() {
        // ここで self.senderStream = nil しなくても、disconnet() した時点で nil になる
        SoraSDKManager.shared.disconnect()
    }
}

#Preview {
    ContentView()
}
