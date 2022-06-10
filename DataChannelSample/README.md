# DataChannelSample (DataChannel メッセージング機能サンプル)

このサンプルでは、 DataChannel メッセージング機能でメッセージを送受信するアプリを Sora iOS SDK を用いて実装する方法を説明しています。
映像とメッセージを同時に送受信するサンプルアプリです。


## ビルド環境

サンプルアプリをビルドするには以下の環境が必要です。

- iOS 13.0 以降がインストールされたデバイス (iPhone / iPad どちらにも対応しています)
  - このサンプルアプリはシミュレータでの動作を保証しません。
- Xcode 13.4 以降
  - 本サンプルアプリでは Swift 5.5.2 を使用しています。
- CocoaPods 1.11.2 以降

## ビルド方法

1. CocoaPods でライブラリを取得します。

   ```
   $ pod install
   ```

2. ``DataChannelSample/Environment.example.swift`` のファイル名を ``DataChannelSample/Environment.swift`` に変更し、接続情報を設定します。

   ```
   $ cp DataChannelSample/Environment.example.swift DataChannelSample/Environment.swift
   ```

３. ``DataChannelSample.xcworkspace`` を Xcode で開いてビルドします。

## サンプルアプリの使い方

このサンプルアプリでは、ビデオチャットと同様の仕様に加えて任意のメッセージを送受信できます。
メッセージの送受信に使うラベルは `Environment.swift` で変更できます。

映像とラベルは関連していません。同一のチャネルに接続したどのクライアントも任意のラベルでメッセージを送信できます。


## 実装上の詳細について

実装上の詳細につきましてはサンプルアプリのソースコード上に詳細なコメントを用意してありますので、適時そちらをご確認ください。
