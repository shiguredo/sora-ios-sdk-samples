# Sora iOS SDK サンプル集

このリポジトリには、 [Sora iOS SDK](https://github.com/shiguredo/sora-ios-sdk) を利用したサンプルアプリを掲載しています。実際の利用シーンに即したサンプルをご用意しておりますので、目的に応じた Sora iOS SDK の使い方を簡単に学ぶことができます。

## About Shiguredo's open source software

We will not respond to PRs or issues that have not been discussed on Discord. Also, Discord is only available in Japanese.

Please read https://github.com/shiguredo/oss before use.

## 時雨堂のオープンソースソフトウェアについて

利用前に https://github.com/shiguredo/oss をお読みください。

## システム条件

このリポジトリの全てのサンプルアプリは、 [Sora iOS SDK 2025.1.1](https://github.com/shiguredo/sora-ios-sdk/releases/tag/2025.1.1) を使用しています。

- iOS 15 以降
- アーキテクチャ arm64 (シミュレーターの動作は未保証)
- macOS 15.0 以降
- Xcode 16.4
- Swift 5.10
- WebRTC SFU Sora 2025.1.0 以降

Xcode と Swift のバージョンによっては、 取得できるバイナリに互換性がない可能性があります。

## ビルド方法

1. ``SamplesApp/Configs/Environment.example.swift`` のファイル名を ``SamplesApp/Configs/Environment.swift`` に変更し、接続情報を設定します。

   ```bash
   cp SamplesApp/Configs/Environment.example.swift SamplesApp/Configs/Environment.swift
   ```

2. ``SamplesApp/SamplesApp.xcodeproj`` を Xcode で開いてビルドします。

   ```bash
   open SamplesApp/SamplesApp.xcodeproj
   ```

> [!TIP]
> はじめてビルドを行う場合、 ビルドに失敗し `SwfitLintBuildToolPlugin (SwiftLintPlugin)` に関するプロンプトが表示されたら
> 必ずプラグインを信頼して有効にしてください。そうすることで次回以降ビルドを正常に実行できます。

## サンプルの紹介

各サンプルは SamplesApp に内包されています。ソースコードは SamplesApp/SamplesApp/Features 下にそれぞれ配置されています。

### VideoChatSample (ビデオチャット)

同じチャネル ID に対して最大で12人までが接続し、同時にビデオチャットに参加できます。
実際に配信されていることを確認したい場合には、複数台のデバイスにこのサンプルアプリをインストールするか、
または他の Sora クライアントを用いて同時に接続する必要があります。

三人以上が同じチャネル ID に対して接続されている場合、画面が複数人で分割されます。
自分自身の配信している動画はポップアップで表示されます。

> [!caution]
12人より多くの人数が同時に接続する場合の挙動については保証されません。

### DecoStreamingSample (デコ動画配信)

カメラで撮影した動画をクライアントサイドで加工して動画配信します。
カメラで撮影した動画を自由に加工して配信できるため、アプリの幅が広がります。

配信を開始したあと、右上のカメラアイコンをタッチすると、自由に動画にフィルタをかけることができます。

> [!important]
> DecoStreamingSample は配信専用となっています。配信している動画を閲覧するには、
> 別途 VideoChatSample (ビデオチャット) などの視聴環境が必要です。

### ScreenCastSample (スクリーンキャスト)

クライアントアプリの画面を動画配信します。ScreenCastSample ではサンプルゲームのプレイ内容を動画配信します。

#### サンプルゲーム

ScreenCastSample 画面に遷移するとサンプルゲームが起動します。
画面をタッチすると物理演算された箱が次々と現れて積み上がっていくゲームになっています。

#### サンプルゲームプレイの配信開始と終了

右上の録画アイコンをタッチすると配信設定後、プレイ中のゲーム画面の配信が開始されます。
右上の停止アイコンをタッチすると配信を終了します。

> [!important]
> ScreenCastSample は配信専用となっています。配信している動画を閲覧するには、
> 別途 VideoChatSample (ビデオチャット) などの視聴環境が必要です。

#### 注意事項

サンプルアプリで使用している ReplayKit の実装都合上、
H.264 形式のビデオフォーマットを使用すると配信が途中で止まる不具合があります。
ReplayKit と同時に使用する場合は、 VP9 などの他のビデオフォーマットでご利用ください。

### SimulcastSample (サイマルキャスト)

サイマルキャスト機能を利用した動画配信とビデオチャットへ参加できます。
VideoChatSample をベースとしています。

> [!TIP]
> サイマルキャストについては https://sora-ios-sdk.shiguredo.jp/simulcast をご確認ください。

### SpotlightSample (スポットライト)

スポットライト機能を利用した動画配信とビデオチャットへ参加できます。
VideoChatSample をベースとしています。

> [!TIP]
> スポットライトについては https://sora-ios-sdk.shiguredo.jp/spotlight をご確認ください。

### DataChannelSample (メッセージング)

ビデオチャットと同様の仕様に加えて任意のメッセージを送受信できます。
メッセージの送受信に使うラベルは `SamplesApp/Configs/Environment.swift` で変更できます。

映像とラベルは関連していません。同一のチャネルに接続したどのクライアントも任意のラベルでメッセージを送信できます。

## ライセンス

Apache License 2.0

```
Copyright 2017-2018, Masashi Ono (akisute)
Copyright 2017-2023, Shiguredo Inc.


Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

このリポジトリに含まれるすべてのアプリアイコン画像（すべての PNG 形式ファイル）のライセンスは [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/deed.ja) です。
