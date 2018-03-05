# DecoStreamingSample (デコ動画配信サンプル)

このサンプルでは、カメラで撮影した動画をクライアントサイドで加工して動画配信するアプリを、
Sora iOS SDK を用いて実装する方法を説明しています。
カメラで撮影した動画を自由に加工して配信できるため、アプリの幅が広がります。

## ビルド環境

サンプルアプリをビルドするには以下の環境が必要です。

- iOS 10.0 以降がインストールされたデバイス (iPhone / iPad どちらにも対応しています)
  - このサンプルアプリはシミュレータでは動作が保証されません。
- Xcode 9.1 以降
  - 本サンプルアプリでは Swift 4.0 を使用しています。
- carthage 0.26.2 以降

## ビルド方法

このサンプルアプリは Carthage によって外部フレームワークの管理を行っているため、
まず最初に以下のように `carthage bootstrap` を実行する必要があります。

```
$ carthage bootstrap
```

これにより、適切に外部フレームワークがセットアップされます。
通常、 Carthage を使用したプロジェクトは Xcode 上で追加の設定が必要ですが、
本サンプルアプリでは既に追加の設定を行っておりますので、これだけで Xcode 上でビルドが可能な状態になります。

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