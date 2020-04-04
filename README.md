# Sora iOS SDK サンプル集

このリポジトリには、 [Sora iOS SDK](https://github.com/shiguredo/sora-ios-sdk) を利用したサンプルアプリを掲載しています。実際の利用シーンに即したサンプルをご用意しておりますので、目的に応じた Sora iOS SDK の使い方を簡単に学ぶことができます。

## About Support

We check PRs or Issues only when written in JAPANESE.
In other languages, we won't be able to deal with them. Thank you for your understanding.

## サポートについて

Sora iOS SDK サンプル集に関する質問・要望・バグなどの報告は Issues の利用をお願いします。
ただし、 Sora のライセンス契約の有無に関わらず、 Issue への応答時間と問題の解決を保証しませんのでご了承ください。

Sora iOS SDK サンプル集に対する有償のサポートについては現在提供しておりません。

## システム条件

このリポジトリの全てのサンプルアプリは、 [Sora iOS SDK 2020.4](https://github.com/shiguredo/sora-ios-sdk/releases/tag/2020.4) を使用しています。

- iOS 10.0 以降
- アーキテクチャ arm64, x86_64 (シミュレーターの動作は未保証)
- macOS 10.15 以降
- Xcode 11.1
- Swift 5.1
- Carthage 0.33.0 以降、または CocoaPods 1.6.1 以降
- WebRTC SFU Sora 19.04.0 以降

Xcode と Swift のバージョンによっては、 Carthage と CocoaPods で取得できるバイナリに互換性がない可能性があります。詳しくはドキュメントを参照してください。

## サンプルの紹介

### RealTimeStreamingSample (生放送配信)

[RealTimeStreamingSample (生放送配信)](/RealTimeStreamingSample)

このサンプルでは、動画生放送の配信・視聴を行うアプリを Sora iOS SDK を用いて実装する方法を説明しています。

### VideoChatSample (ビデオチャット)

[VideoChatSample (ビデオチャット)](/VideoChatSample)

このサンプルでは、複数人が同時に参加できるビデオチャットアプリを Sora iOS SDK を用いて実装する方法を説明しています。

### DecoStreamingSample (デコ動画配信)

[DecoStreamingSample (デコ動画配信)](/DecoStreamingSample)

このサンプルでは、カメラで撮影した動画をクライアントサイドで加工して動画配信するアプリを Sora iOS SDK を用いて実装する方法を説明しています。

### ScreenCastSample (スクリーンキャスト)

[ScreenCastSample (スクリーンキャスト)](/ScreenCastSample)

このサンプルでは、クライアントアプリの画面を動画配信するアプリを Sora iOS SDK を用いて実装する方法を説明しています。

## ライセンス

このリポジトリに含まれる全てのリソースは Apache License Version 2.0 のもとで公開されています。
詳細につきましては [LICENSE](/LICENSE) ファイルをご参照ください。

# Copyright

Copyright 2017-2019, Shiguredo Inc. and Masashi Ono (akisute)
