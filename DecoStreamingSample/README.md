# DecoStreamingSample (デコ動画配信サンプル)

このサンプルでは、カメラで撮影した動画をクライアントサイドで加工して動画配信するアプリを、
Sora iOS SDK を用いて実装する方法を説明しています。
カメラで撮影した動画を自由に加工して配信できるため、アプリの幅が広がります。

## ビルド環境

サンプルアプリをビルドする際の環境については [システム条件](../README.md#システム条件) をご確認ください。

## ビルド方法

1. CocoaPods でライブラリを取得します。

   ```
   $ pod install
   ```

2. ``DecoStreamingSample/Environment.example.swift`` のファイル名を ``DecoStreamingSample/Environment.swift`` に変更し、接続情報を設定します。

   ```
   $ cp DecoStreamingSample/Environment.example.swift DecoStreamingSample/Environment.swift
   ```

３. ``DecoStreamingSample.xcworkspace`` を Xcode で開いてビルドします。

## サンプルアプリの使い方

配信を開始したあと、右上のカメラアイコンをタッチすると、自由に動画にフィルタをかけることができます。

このサンプルアプリは配信専用となっています。
このサンプルアプリで配信している動画を閲覧するには、
別途 RealTimeStreamingSample (生放送配信サンプルアプリ) などの視聴環境が必要です。

このサンプルアプリでは、同時に複数のクライアントが同じクライアントIDに接続して配信を行う事はできません。
最初に接続した配信者が優先され、後から同じクライアントIDに接続した配信者はエラーになります。
視聴者側には特に制限がなく、無制限に配信を見る事ができます。

## 実装上の詳細について

実装上の詳細につきましてはサンプルアプリのソースコード上に詳細なコメントを用意してありますので、適時そちらをご確認ください。
