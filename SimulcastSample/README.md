# SimulcastSample (サイマルキャスト)

このサンプルでは、サイマルキャスト機能を使用する方法を説明しています。 VideoChatSample のコードをベースにしています。

## ビルド環境

サンプルアプリをビルドする際の環境については [システム条件](../README.md#システム条件) をご確認ください。

## ビルド方法

1. ``SimulcastSample/Environment.example.swift`` のファイル名を ``SimulcastSample/Environment.swift`` に変更し、接続情報を設定します。

   ```
   $ cp SimulcastSample/Environment.example.swift SimulcastSample/Environment.swift
   ```

2. ``SimulcastSample.xcodeproj`` を Xcode で開いてビルドします。

   ```
   $ open SimulcastSample.xcodeproj
   ```

> [!TIP]
> はじめてビルドを行う場合、 ビルドに失敗し `SwfitLintBuildToolPlugin (SwiftLintPlugin)` に関するプロンプトが表示されたら
> 必ずプラグインを信頼して有効にしてください。そうすることで次回以降ビルドを正常に実行できます。

## サンプルアプリの使い方

このサンプルアプリでは、同じクライアントIDに対して最大で12人までが接続し、同時にビデオチャットに参加できます。
それ以上の人数が同時に接続する場合の挙動については保証されません。
実際に配信されていることを確認したい場合には、複数台のデバイスにこのサンプルアプリをインストールするか、
または他の Sora クライアントを用いて同時に接続する必要があります。

三人以上が同じクライアントIDに対して接続されている場合、画面が複数人で分割されます。

自分自身の配信している動画はポップアップで表示されます。

## 実装上の詳細について

実装上の詳細につきましてはサンプルアプリのソースコード上に詳細なコメントを用意してありますので、適時そちらをご確認ください。
