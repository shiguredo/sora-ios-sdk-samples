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

### misc

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
