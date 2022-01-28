# SpotlightSample (スポットライト)

このサンプルでは、スポットライト機能を使用する方法を説明しています。 VideoChatSample と SimulcastSample のコードをベースにしています。

## ビルド環境

サンプルアプリをビルドするには以下の環境が必要です。

- iOS 13.0 以降がインストールされたデバイス (iPhone / iPad どちらにも対応しています)
  - このサンプルアプリはシミュレータでは動作が保証されません。
- Xcode 13.1 以降
  - 本サンプルアプリでは Swift 5.5 を使用しています。
- CocoaPods 1.11.2 以降

## ビルド方法

1. CocoaPods でライブラリを取得します。

   ```
   $ pod install
   ```

2. (develop ブランチの場合) ``SpotlightSample/Environment.example.swift`` のファイル名を ``SpotlightSample/Environment.swift`` に変更し、接続情報を設定します。

   ```
   $ cp SpotlightSample/Environment.example.swift SpotlightSample/Environment.swift
   ```

３. ``SpotlightSample.xcworkspace`` を Xcode で開いてビルドします。

## サンプルアプリの使い方

このサンプルアプリでは、同じクライアントIDに対して最大で12人までが接続し、同時にビデオチャットに参加できます。
それ以上の人数が同時に接続する場合の挙動については保証されません。
実際に配信されていることを確認したい場合には、複数台のデバイスにこのサンプルアプリをインストールするか、
または他の Sora クライアントを用いて同時に接続する必要があります。

三人以上が同じクライアントIDに対して接続されている場合、画面が複数人で分割されます。

自分自身の配信している動画はポップアップで表示されます。

## 実装上の詳細について

実装上の詳細につきましてはサンプルアプリのソースコード上に詳細なコメントを用意してありますので、適時そちらをご確認ください。
