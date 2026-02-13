# 変更履歴

- CHANGE
  - 下位互換のない変更
- UPDATE
  - 下位互換がある変更
- ADD
  - 下位互換がある追加
- FIX
  - バグ修正

## 2025.3

- [CHANGE] 全てのサンプルを SamplesApp に統合する
  - SamplesApp 起動後にメインメニューから DataChannel、DecoStreaming、ScreenCast、Simulcast、Spotlight、VideoChat の各サンプル機能に遷移できるようにする
  - 個別のサンプルプロジェクトを削除する
  - @t-miya
- [CHANGE] SimulcastSample の設定値である SimulcastRid を SimulcastRequestRid に移行する
  - これによりシステム条件の WebRTC SFU Sora のバージョンが 2025.2.0 以降になる
  - @zztkm
- [UPDATE] DataChannel Sample の横画面での配信時レイアウトを変更する
  - 左右分割で、左側に映像、右側にメッセージ欄のレイアウトにする
  - @t-miya
- [UPDATE] 接続時カメラ有効設定の値を `Configuration.initialCameraEnabled` に渡すようにする
  - @t-miya
- [UPDATE] 各サンプル個別の SoraSDKManager を統合する
  - DataChannel、DecoStreaming、ScreenCast、Simulcast、Spotlight、VideoChat それぞれの XXSoraSDKManager を廃止し、 Shared/SoraSDKManager を利用するようにする
  - @t-miya
- [UPDATE] 映像ハードミュートを MediaChannel.setVideoHardMute(Bool) 利用で実行するようにする
  - DataChannel、Simulcast、Spotlight、VideoChat それぞれの映像ハードミュート処理に適用する
  - `接続時カメラ有効` 設定を無効で開始した際の映像ハードミュートも MediaChannel.setVideoHardMute(Bool) を利用する
  - @t-miya
- [UPDATE] 映像ソフトミュートを MediaChannel.setVideoSoftMute(Bool) 利用で実行するようにする
  - DataChannel、Simulcast、Spotlight、VideoChat それぞれの映像ソフトミュート処理に適用する
  - @t-miya
- [UPDATE] システム条件を変更する
  - Xcode 26.1.1
  - WebRTC SFU Sora 2025.2.0 以降
  - @zztkm
- [UPDATE] ロギングを NSLog から os.Logger に置き換える
  - SamplesLogger モジュールを追加し、NSLog の使用箇所を置き換える
  - @t-miya
- [UPDATE] ScreenCastSample の配信開始/停止ボタンアイコンを置き換える
  - 開始を `camera` から `record.circle` の置き換える
  - 停止を `pause` から `stop.circle.fill` に置き換える
  - @t-miya
- [UPDATE] 前面カメラ・背面カメラの切り替えボタンアイコンを置き換える
  - `camera` から `camera.rotate` に置き換える
  - @t-miya
- [ADD] 接続メニューに `開始時マイク有効` 項目を追加する
  - DataChannel、Simulcast、Spotlight、VideoChat が対象
  - `無効` で接続した場合は音声ハードミュート相当の状態で開始する
  - @t-miya
- [ADD] 音声ハードミュート機能を追加する
  - DataChannel、Simulcast、Spotlight、VideoChat が対象
  - 録音 -> ソフトミュート -> ハードミュート -> 録音 と遷移するようにマイクミュートボタンの挙動を変更する
  - 音声ミュート制御モジュールとして AudioMuteController を追加する
  - 音声ソフトミュート切り替えは MediaChannel.setAudioSoftMute(Bool) を利用するようにする
  - @t-miya
- [ADD] 接続メニューに `接続時カメラ有効` 項目を追加する
  - DataChannel、Simulcast、Spotlight、VideoChat が対象
  - `無効` で接続した場合は映像ハードミュート相当の状態で開始する
  - @t-miya
- [ADD] カメラハードミュート機能を追加する
  - DataChannel、Simulcast、Spotlight、VideoChat が対象
  - 録画 -> ソフトミュート -> ハードミュート -> 録画 と遷移するようにカメラミュートボタンの挙動を変更する
  - 映像ミュート制御モジュールとして CameraMuteController を追加する
  - ハードミュート中は前面カメラ・背面カメラの切り替えボタンを無効にする
  - @t-miya
- [ADD] 映像ビットレート指定を追加する
  - `Video Chat Sample`、`Simulcast Sample`、`Spotlight Sample` に追加
  - @zztkm
- [ADD] カメラミュートボタンとマイクミュートボタンを追加する
  - 対象: DataChannelSample、SimulcastSample、SpotlightSample、VideoChatSample
  - カメラは黒塗りフレーム、マイクは無音フレームを送信するソフトミュート
  - @t-miya
- [ADD] RPC サンプルを追加する
  - Sora SDK の RPC 機能を実装・利用するためのサンプルアプリケーション
  - @zztkm
- [ADD] 共有ユーティリティ AnyCodable を追加する
  - Any 型の値を JSON エンコード/デコード可能にするラッパー型
  - 動的な JSON を扱う場合に利用する
  - @zztkm
- [FIX] VideoChat、Simulcast、Spotlight Sample にて画面回転時にセルフビューの一部が画面外になってしまう不具合を修正する
  - @t-miya
- [FIX] DataChannel Sample にて画面回転時にセルフビューが表示されなくなる不具合を修正する
  - @t-miya
- [UPDATE] SamplesApp のアプリ表示名を `ビデオチャット` から `Sora Samples` に修正する
  - @zztkm

### misc

- [UPDATE] Github Actions のビルド環境を更新する
  - Xcode の version を 26.2 に変更
  - SDK を iOS 26.2 に変更
- [UPDATE] actions/checkout を v5 に上げる
  - @miosakuma
- [UPDATE] `Claude Assistant` の `claude-response` を `ubuntu-slim` に移行する
  - @zztkm

## sora-ios-sdk-2025.2.0

**リリース日**: 2025-09-18

- [CHANGE] マルチストリーム設定を廃止する
  - レガシーストリーム機能は 2025 年 6 月リリースの Sora にて廃止されたため、サンプルアプリケーションでもマルチストリーム設定を廃止する
  - Sora がデフォルトでレガシーストリームを使用するように設定されている場合、接続エラーになる
  - @t-miya
- [UPDATE] onDisconnect 時のログを詳細化する
  - SoraEvent の内容を出力する処理を追加
  - @miosakuma

### misc

- [UPDATE] Github Actions のビルド環境を更新する
  - Xcode の version を 16.3 に変更
  - SDK を iOS 18.3 に変更
- [CHANGE] フォーマッターを SwiftFormat から swift-format に変更する
  - SwiftFormat のための設定ファイルである `.swiftformat` と `.swift-version` を削除
  - フォーマット設定はデフォルトを採用したため、`.swift-format` は利用しない
  - https://github.com/swiftlang/swift-format
  - @zztkm
- [UPDATE] 依存管理を CocoaPods から Xcode の Swift Package Manager に移行する
  - Sora と SwiftLint を Swift Package Manager 管理に移行する
    - SwiftLint を直接インストールするのではなく、ビルド済 SwiftLint と Xcode 統合のためのプラグインを提供する SwiftLintPlugin 経由で利用
    - SwiftLintPlugin を Xcode で初めて利用する場合の注意事項と対応方法を各アプリの README に記載
  - GitHub Actions から CocoaPods 関連処理を削除
  - CocoaPods への依存をなくしたため、Podfile を削除
  - @zztkm
- [UPDATE] SwiftLint の実行をシェルスクリプトではなく、Xcode の Build Phases に設定
  - これにより、ビルド時に SwiftLint が実行されるようになる
  - ビルド時に SwiftLint を実行するようになったため、lint-format.sh から SwiftLint を削除
  - @zztkm
- [UPDATE] フォーマッターとリンターの実行を Makefile と Xcode に分割したため、不要になった lint-format.sh を削除
  - @zztkm
- [UPDATE] swift-format lint で出力される警告を修正
  - @zztkm
- [UPDATE] GitHub Actions の定期実行をやめる
  - @zztkm
- [UPDATE] GitHub Actions のビルド環境を更新する
  - runner を macos-15 に変更
  - Xcode の version を 16.2 に変更
  - SDK を iOS 18.2 に変更
  - @zztkm
- [ADD] swift-format 実行用の Makefile を追加する
  - lint-format.sh で一括実行していたコマンドを個別に実行できるようにした
  - デフォルトでは make コマンドを実行したディレクトリから再帰的に .swift ファイルを探すが、`TARGET_PATH` 変数を与えることで特定のディレクトリ以下の .swift ファイルを対象にすることも可能
  - @zztkm
- [ADD] .github ディレクトリに copilot-instructions.md を追加
  - @torikizi
- [ADD] SoraiOSSDKSamples.xcworkspace を追加する
  - 1つの Xcode で複数のプロジェクトを管理するためのワークスペース

## sora-ios-sdk-2025.1.3

**リリース日**: 2025-07-28

- [UPDATE] Sora iOS SDK を 2025.1.3 にあげる
  - @zztkm

## sora-ios-sdk-2025.1.2

**リリース日**: 2025-05-07

- [UPDATE] Sora iOS SDK を 2025.1.2 にあげる
  - @zztkm

## sora-ios-sdk-2025.1.1

**リリース日**: 2025-01-23

- [UPDATE] Sora iOS SDK を 2025.1.1 にあげる
  - @miosakuma

## sora-ios-sdk-2025.1.0

**リリース日**: 2025-01-21

- [UPDATE] CocoaPods の platform の設定を 14.0 に上げる
  - @miosakuma
- [UPDATE] システム条件を変更する
  - iOS 14 以降
  - macOS 15.0 以降
  - Xcode 16.0
  - @miosakuma
- [UPDATE] 映像コーデックタイプの並び順を変更する
  - VP8 / VP9 / AV1 / H.264/ H.265 の順番になるように変更
  - @zztkm
- [ADD] 映像コーデックタイプに H.265 を追加する
  - @zztkm
- [ADD] none 項目がなかった `SimulcastSample` と `SpotlightSample` に none を追加
  - @zztkm

## sora-ios-sdk-2024.3.0

**リリース日**: 2024-09-06

- [UPDATE] 各サンプルの libwebrtc のログレベルを RTCLoggingSeverityNone から RTCLoggingSeverityInfo にする
  - libwebrtc のログを INFO レベルで出力するようにする
  - @zztkm
- [UPDATE] GitHub Actions の Xcode のバージョンを 15.4 にあげる
  - 合わせて iOS の SDK を iphoneos17.5 にあげる
  - @miosakuma
- [UPDATE] システム条件を変更する
  - macOS 14.6.1 以降
  - Xcode 15.4
  - WebRTC SFU Sora 2024.1.0 以降
  - @miosakuma

## sora-ios-sdk-2024.2.0

- [UPDATE] Github Actions を actions/cache@v4 にあげる
  - @miosakuma
- [UPDATE] Github Actions を macos-14  にあげる
  - @miosakuma
- [UPDATE] Github Actions を Xcode 15.2, iphoneos17.2 にあげる
  - @miosakuma
- [UPDATE] Github Actions のビルドオプションに `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS=NO` を追加する
  - Xcode 15 で Asset のシンボルである、GeneratedAssetSymbols.swift が生成されるようになったがこのファイルが SwiftFormat エラー対象となる
  - CI では Asset のシンボル生成は不要であるため生成しないようオプション指定を行う
  - [Xcode 15 リリースノート - Asset Catalogs](https://developer.apple.com/documentation/xcode-release-notes/xcode-15-release-notes#Asset-Catalogs)
  - @miosakuma
- [UPDATE] システム条件を変更する
  - macOS 14.4.1 以降
  - Xcode 15.3
  - Swift 5.10
  - @miosakuma

## sora-ios-sdk-2024.1.0

- [UPDATE] システム条件を変更する
  - macOS 14.3.1 以降
  - WebRTC SFU Sora 2023.2.0 以降
  - Xcode 15.2
  - Swift 5.9.2
  - CocoaPods 1.15.2 以降
  - @miosakuma

## sora-ios-sdk-2023.3.1

- [UPDATE] Sora iOS SDK を 2023.3.1 にあげる
  - @miosakuma

## sora-ios-sdk-2023.3.1

- [UPDATE] SwiftLint, SwiftFormat/CLI を一時的にコメントアウトする
  - SwiftLint, SwiftFormat/CLI が Swift Swift 5.9 に対応できていないため
  - 対応が完了したら戻す
  - @miosakuma
- [FIX] VideoChatSample で signalingConnectMetadata が設定できない不具合を修正
  - @miosakuma

## sora-ios-sdk-2023.2.0

- [ADD] DataChannelSample の映像コーデックに AV1 を追加する
  - @miosakuma
- [ADD] DecoStreamingSample の映像コーデックに AV1 を追加する
  - @miosakuma
- [ADD] ScreenCastSample の映像コーデックに AV1 を追加する
  - @miosakuma
- [ADD] SimulcastSample の映像コーデックに VP9 と AV1 を追加する
  - @miosakuma
- [ADD] VideoChatSample の映像コーデックに AV1 を追加する
  - @miosakuma
- [ADD] VideoChatSample に映像コーデックプロファイル設定を追加する
  - @miosakuma
- [UPDATE] システム条件を変更する
  - macOS 13.4.1 以降
  - Xcode 14.3.1
  - Swift 5.8.1
  - WebRTC SFU Sora 2023.1.0 以降
  - CocoaPods 1.12.1 以降
  - @miosakuma
- [FIX] ScreenCastSample の H.264 の映像が送信されない不具合を修正する
  - 画像を半分にリサイズしてエンコード可能なサイズとする
  - @szktty

## sora-ios-sdk-2023.1.0

- [UPDATE] システム条件を変更する
  - macOS 13.3 以降
  - Xcode 14.3
  - Swift 5.8
  - WebRTC SFU Sora 2022.2.0 以降
  - CocoaPods 1.12.0 以降
  - @miosakuma

## sora-ios-sdk-2022.6.0

- [CHANGE] システム条件を変更する
  - アーキテクチャ から x86_64 を削除
  - macOS 12.6 以降
  - Xcode 14.0
  - Swift 5.7
  - CocoaPods 1.11.3 以降
  - @miosakuma

## sora-ios-sdk-2022.5.0

- [UPDATE] システム条件を変更する
  - WebRTC SFU Sora 2022.1.1 以降
  - Xcode 13.4.1
  - @miosakuma
- [FIX] DecoStreamingSample の iOS 14 初期に発生していたクラッシュ不具合の暫定処理を削除
  - iOS 14.6 で問題が解消されていたため当初の処理に戻す
  - @szktty

## sora-ios-sdk-2022.4.0

- [UPDATE] システム条件を変更する
  - macOS 12.3 以降
  - WebRTC SFU Sora 2022.1.0 以降
  - @miosakuma
- [ADD] VideoChatSample, SimulcastSample, SpotlightSample で bundle_id を設定する
  - @enm10k
- [ADD] SpotlightSample の映像コーデックに VP9 を追加する
  - @enm10k
- [ADD] SpotlightSample サイマルキャストの有効・無効を切り替える設定を追加する
  - @enm10k

## sora-ios-sdk-2022.3.0

- [UPDATE] DecoStreamingSample をマルチストリームにする
  - @szktty
- [UPDATE] ScreenCastSample をマルチストリームにする
  - @miosakuma
- [ADD] サーバから切断されたとき接続前の状態に戻る
  - @szktty
- [CHANGE] RealTimeStreamingSample を廃止する
  - @miosakuma

## sora-ios-sdk-2022.2.0

- [UPDATE] Github Actions でのビルド処理で利用する Podfile を Podfile.dev から Podfile に変更する
  - @miosakuma
- [UPDATE] Environment.example.swift に signalingConnectMetadata を追加する
  - @miosakuma
- [ADD] DataChannelSample の追加する
  - @szktty
- [FIX] 接続ボタンを連打された際に複数の接続が作成される不具合を修正する
  - @szktty, @miosakuma
