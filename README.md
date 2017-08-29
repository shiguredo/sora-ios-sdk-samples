# Sora iOS SDK サンプル集

このリポジトリには、 [Sora iOS SDK](https://github.com/shiguredo/sora-ios-sdk) を利用したサンプルアプリを掲載しています。実際の利用シーンに即したサンプルをご用意しておりますので、目的に応じた Sora iOS SDK の使い方を簡単に学ぶことができます。

## ビルド環境

このリポジトリの全てのサンプルアプリは、 [Sora iOS SDK 1.2.3](https://github.com/shiguredo/sora-ios-sdk/releases/tag/1.2.3) を使用しています。

サンプルアプリをビルドするには以下の環境が必要です。

- iOS 10.0 以降がインストールされたデバイス (iPhone / iPad どちらにも対応しています)
  - サンプルアプリはシミュレータでは動作が保証されません。必ず実機でご利用ください。
- Xcode 8.3.3 以降
  - サンプルアプリでは Swift 3.1 を使用しています。
- carthage 0.23.0 以降
  - サンプルアプリをビルドする際に必須となります。

## サンプルの紹介

### RealTimeStreamingSample (生放送配信)

[RealTimeStreamingSample (生放送配信)](https://github.com/shiguredo/sora-ios-sdk-samples/tree/master/RealTimeStreamingSample)

このサンプルでは、動画生放送の配信・視聴を行うアプリを Sora iOS SDK を用いて実装する方法を説明しています。
また、スナップショット機能の使用方法についても解説しています。

### VideoChatSample (ビデオチャット)

[VideoChatSample (ビデオチャット)](https://github.com/shiguredo/sora-ios-sdk-samples/tree/master/VideoChatSample)

このサンプルでは、複数人が同時に参加できるビデオチャットアプリを Sora iOS SDK を用いて実装する方法を説明しています。

## ライセンス

このリポジトリに含まれる全てのリソースは Apache License Version 2.0 のもとで公開されています。
詳細につきましては [LICENSE](https://github.com/shiguredo/sora-ios-sdk-samples/tree/master/LICENSE) ファイルをご参照ください。