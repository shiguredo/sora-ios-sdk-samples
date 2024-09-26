import Sora
import SwiftUI

struct VideoChatRoomView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var senderStream: MediaStream?

    // 受信用のストリームです。
    // @State を指定しているので、このプロパティに変更があると
    // 受信者リストビューが再描画されます。
    @State private var receiverStreams: [MediaStream] = []

    @State private var showsAlert = false
    
    // 接続時のエラー
    @State private var connectionError: Error?

    // 接続に成功したら true にします。
    // true にすると映像画面に遷移します。
    @State private var isConnect: Bool?

    var mediaChannel: MediaChannel? {
        SoraSDKManager.shared.currentMediaChannel
    }

    var body: some View {
        NavigationStack {
            // 受信映像の上に小さいサイズの配信映像を重ねて表示します。
            VStack {
                ZStack {
                    ReceiversView(receiverStreams, columnCount: 2)

                    VStack {
                        // スペースを上と左にいれて右下に映像ビューを配置します。
                        Spacer()
                        HStack {
                            Spacer()
                            // iOS SDK で提供している SwiftUI 用 Video view
                            Video(senderStream)
                                // 映像を引き伸ばしてビューを埋めます。
                                .videoAspect(.fill)
                                .frame(width: 110, height: 170)
                                .border(Color.white, width: 2)
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                        }
                    }
                }
                HStack {
                    Button {
                        startVideoChat()
                    } label: {
                        Text("スタート")
                            .font(.title)
                    }
                    Button {
                        stopVideoChat()
                    } label: {
                        Text("ストップ")
                            .font(.title)
                    }
                }
            }
        }
        .navigationTitle("\(mediaChannel?.configuration.channelId ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        // ビューが最初に描画されたときの処理です。
        .onAppear {
            onForeground()
        }

        // ビューがバックグラウンドを往復したときの処理です。
        // TODO(zztkm) onChange(of:perform:) は非推奨のようなので更新する
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                onBackground()
            case .active:
                onForeground()
            default:
                print("kensaku: break")
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
    
    func startVideoChat() {
        SoraSDKManager.shared.connect(channelId: AppEnvironment.channelId, role: .sendrecv, multistreamEnabled: true)
        { error in
            if let error = error {
                self.connectionError = error
                self.showsAlert = true
                return
            }
        }
        // 接続確立フラグ
        isConnect = true
    }
    
    func stopVideoChat() {
        SoraSDKManager.shared.disconnect()
        isConnect = false
    }

    // ビューがフォアグラウンドに遷移したときの処理です。
    // このビデオチャットではチャット中に別のクライアントが入室したり退室したりする可能性があります。
    // 入室退室が発生したら都度動画の表示を更新しなければなりませんので、そのためのコールバックを設定します。
    func onForeground() {
        guard let mediaChannel = mediaChannel else {
            return
        }

        senderStream = mediaChannel.senderStream
        receiverStreams = mediaChannel.receiverStreams

        // 同チャネルに接続が追加されたときのコールバックを設定します。
        mediaChannel.handlers.onAddStream = { _ in
            NSLog("[sample] mediaChannel.handlers.onAddStream")
            // 受信ストリームを更新します。
            // receiverStreams プロパティは監視対象なので、
            // 新しいリストを代入するとビューが再描画されて受信映像リストが更新されます。
            self.receiverStreams = mediaChannel.receiverStreams
        }

        // 同チャネルへの接続が減ったときのコールバックを設定します。
        mediaChannel.handlers.onRemoveStream = { _ in
            NSLog("[sample] mediaChannel.handlers.onRemoveStream")
            // 受信ストリームの追加時と同様に receiverStreams プロパティを更新します。
            self.receiverStreams = mediaChannel.receiverStreams
        }

        // サーバーから切断されたときのコールバックを設定します。
        mediaChannel.handlers.onDisconnect = { _ in
            NSLog("[sample] mediaChannel.handlers.onDisconnect")
            // 本アプリでは特に行うべき処理はありません。
        }
    }

    // ビューがバックグラウンドに遷移したときの処理です。
    func onBackground() {
        // コールバックを削除します。
        if let mediaChannel = mediaChannel {
            mediaChannel.handlers.onAddStream = nil
            mediaChannel.handlers.onRemoveStream = nil
            mediaChannel.handlers.onDisconnect = nil
        }
    }
}

// 受信ストリームの映像を格子状に並べるビューです。
struct ReceiversView: View {
    // 一つの列に並べるストリームのリストです。
    // ForEach で使います。
    struct Row: Identifiable {
        var id = UUID()

        var streams: [MediaStream]

        init(_ streams: [MediaStream]) {
            self.streams = streams
        }
    }

    var streams: [MediaStream]
    var rows: [Row]

    init(_ streams: [MediaStream], columnCount: Int) {
        self.streams = streams

        // 表示用に配置したストリームのリストを先に用意しておきます。
        let rowCount = (streams.count / columnCount) + (streams.count % columnCount > 0 ? 1 : 0)
        rows = []
        for i in 0 ..< rowCount {
            var rowStreams: [MediaStream] = []
            for j in 0 ..< columnCount {
                let k = i * columnCount + j
                if k < streams.count {
                    rowStreams.append(streams[k])
                }
            }
            rows.append(Row(rowStreams))
        }
    }

    var body: some View {
        // 映像ビューを格子状に配置します。
        VStack {
            ForEach(rows, id: \.id) { row in
                HStack {
                    // ストリームのリストは streamId プロパティで識別可能です。
                    ForEach(row.streams, id: \.streamId) { stream in
                        Video(stream)
                            // 映像を引き伸ばしてビューを埋めます。
                            .videoAspect(.fill)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    VideoChatRoomView()
}
