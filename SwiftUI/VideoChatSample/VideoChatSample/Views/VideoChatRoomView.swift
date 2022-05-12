import Sora
import SwiftUI

struct VideoChatRoomView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var senderStream: MediaStream?

    @State private var showsAlert = false

    // 接続時のエラーです。
    @State private var connectionError: Error?

    var mediaChannel: MediaChannel? {
        SoraSDKManager.shared.currentMediaChannel
    }

    var body: some View {
        NavigationView {
            // 受信映像の上に小さいサイズの配信映像を重ねて表示します。
            ZStack {
                // Video($receiverStream)

                VStack {
                    // スペースを上と左にいれて右下に映像ビューを配置します。
                    Spacer()
                    HStack {
                        Spacer()
                        Video($senderStream)
                            .frame(width: 110, height: 170)
                            .border(Color.white, width: 2)
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("\(mediaChannel?.configuration.channelId ?? "")")
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {
            ToolbarItem {
                Button {
                    flipCamera()
                } label: {
                    Image(systemName: "camera")
                }
            }
        }

        // ビューが最初に描画されたときの処理です。
        .onAppear {
            onForeground()
        }

        // ビューがバックグラウンドを往復したときの処理です。
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                onBackground()
            case .active:
                onForeground()
            default:
                break
            }
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

    // ビューがフォアグラウンドに遷移したときの処理です。
    // このビデオチャットではチャット中に別のクライアントが入室したり退室したりする可能性があります。
    // 入室退室が発生したら都度動画の表示を更新しなければなりませんので、そのためのコールバックを設定します。
    func onForeground() {
        guard let mediaChannel = mediaChannel else {
            return
        }

        senderStream = mediaChannel.senderStream

        /*
         if let mediaChannel = SoraSDKManager.shared.currentMediaChannel {
             mediaChannel.handlers.onAddStream = { [weak self] _ in
                 NSLog("[sample] mediaChannel.handlers.onAddStream")
                 DispatchQueue.main.async {
                     self?.handleUpdateStreams()
                 }
             }
             mediaChannel.handlers.onRemoveStream = { [weak self] _ in
                 NSLog("[sample] mediaChannel.handlers.onRemoveStream")
                 DispatchQueue.main.async {
                     self?.handleUpdateStreams()
                 }
             }

             // サーバーから切断されたときのコールバックを設定します。
             mediaChannel.handlers.onDisconnect = { [weak self] _ in
                 NSLog("[sample] mediaChannel.handlers.onDisconnect")
                 DispatchQueue.main.async {
                     self?.handleDisconnect()
                 }
             }
         }

         // その後、動画の表示を初回更新します。次回以降の更新は直前に設定したコールバックが行います。
         handleUpdateStreams()
          */
    }

    // ビューがバックグラウンドに遷移したときの処理です。
    func onBackground() {
        // バックグラウンド時にコールバックを削除します。
        if let mediaChannel = mediaChannel {
            mediaChannel.handlers.onAddStream = nil
            mediaChannel.handlers.onRemoveStream = nil
            mediaChannel.handlers.onDisconnect = nil
        }
    }

    func flipCamera() {
        guard let current = CameraVideoCapturer.current else {
            return
        }

        guard current.isRunning else {
            return
        }

        CameraVideoCapturer.flip(current) { error in
            if let error = error {
                NSLog("[sample] " + error.localizedDescription)
            }
        }
    }
}

struct VideoChatRoomView_Previews: PreviewProvider {
    static var previews: some View {
        VideoChatRoomView()
    }
}
