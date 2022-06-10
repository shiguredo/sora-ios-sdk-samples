# 変更履歴

- UPDATE
    - 下位互換がある変更
- ADD
    - 下位互換がある追加
- CHANGE
    - 下位互換のない変更
- FIX
    - バグ修正

## develop

- [UPDATE] DecoStreamingSample をマルチストリームにする
    - @szktty
- [UPDATE] RealTimeStreamingSample をマルチストリームにする
    - @szktty
- [UPDATE] ScreenCastSample をマルチストリームにする
    - @miosakuma
- [ADD] サーバから切断されたとき接続前の状態に戻る
    - @szktty
- [CHANGE] RealTimeStreamingSample を廃止する
    - @miosakuma

## sora-ios-sdk-2022.2.0

- [UPDATE] Github Actions でのビルド処理で利用する Podfile を Podfile.dev からPodfile に変更する 
    - @miosakuma
- [UPDATE] Environment.example.swift に signalingConnectMetadata を追加する 
    - @miosakuma
- [ADD] DataChannelSample の追加する
    - @szktty
- [FIX] 接続ボタンを連打された際に複数の接続が作成される不具合を修正する
    - @szktty, @miosakuma
