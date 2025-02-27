---
layout: default
title: "Windowsのバッチファイルで環境別の設定をおこなう方法"
category: "configuration deployment"
---

タスクスケジューラーから実行されるバッチファイルが、どのフォルダからでも正しく動作するようにするには、バッチファイル内で現在のスクリプトのディレクトリを取得し、そのディレクトリを基準に設定ファイルを参照するようにします。以下の方法で、フォルダ構成を意識しないバッチファイルを作成できます。

1. config.bat の例

このファイルは、c:\batch\config.bat に配置されていると仮定します。
```
:: config.bat
set MY_VAR1=value1
set MY_VAR2=value2
set MY_VAR3=value3
```

2. main.bat の例

main.bat ファイルでは、スクリプトのディレクトリを取得して、そのディレクトリを基準に config.bat を読み込みます。

```
:: main.bat
@echo off

:: スクリプトが配置されているディレクトリを取得
set "SCRIPT_DIR=%~dp0"

:: 設定ファイルをスクリプトのディレクトリから読み込む
call "%SCRIPT_DIR%config.bat"

:: 環境変数を使った処理
echo MY_VAR1 is %MY_VAR1%
echo MY_VAR2 is %MY_VAR2%
echo MY_VAR3 is %MY_VAR3%

:: 実行したいコマンド
mkdir %MY_VAR1%
```

3. バッチファイルの実行

タスクスケジューラーから main.bat を実行すると、config.bat の環境変数を正しく読み込んで処理を実行します。%~dp0 は、現在のバッチファイルが置かれているディレクトリのパスを取得する特殊な変数です。

このようにすることで、どのディレクトリからでも正しくバッチファイルを実行でき、タスクスケジューラーや他の実行環境からの影響を受けにくくなります。
