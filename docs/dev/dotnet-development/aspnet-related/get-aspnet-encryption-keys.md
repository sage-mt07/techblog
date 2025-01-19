---
layout: default
title: "ASP.NET レジストリに関連する暗号化キーの一覧を取得する方法"
category: "dotnet develop"
---
# ASP.NET レジストリに関連する暗号化キーの一覧を取得する方法

## 前提
ASP.NETの構成ファイルを暗号化する際に使用される暗号化キー（RSAキーコンテナ）を取得する必要があります。`aspnet_regiis`コマンドには、直接的にキーコンテナの名前の一覧を表示する機能がありませんが、他の手法でキーの一覧を取得できます。

## キーコンテナの一覧を取得する方法

### certutil コマンドを使用する
`certutil`コマンドを使用して、マシン上に存在するRSAキーコンテナの一覧を取得することができます。

```bash
certutil -key
```

このコマンドを実行すると、マシン上に存在するすべてのRSAキーコンテナの名前が表示されます。これには、aspnet_regiisで使用されるキーコンテナも含まれます。

参考情報
キーの保存場所:
マシンレベルのキー: C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys
ユーザーレベルのキー: C:\Users\username\AppData\Roaming\Microsoft\Crypto\RSA
これらのディレクトリにアクセスして、キーコンテナのファイル自体を確認することも可能です。

注意事項
aspnet_regiisコマンド自体には、キーコンテナの名前を直接リストする機能がないため、certutilコマンドを使用することを推奨します。
