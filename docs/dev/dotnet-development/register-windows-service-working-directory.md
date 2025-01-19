---
layout: default
title: "Windows Service登録とワーキングディレクトリの設定"
category: "dotnet develop"
---
# Windows Service登録とワーキングディレクトリの設定

SCコマンドを使用してWindowsサービスを登録する際に、ワーキングディレクトリを指定する直接的なオプションはありません。ただし、ワーキングディレクトリを設定するために、サービスを実行する実行ファイル内で明示的に設定するか、サービスが起動したときにスクリプトやバッチファイルを使って設定する方法があります。

もしSCコマンドでサービスを登録する際に、指定したいワーキングディレクトリがある場合、以下のような方法を考えることができます。

バッチファイルを使う: サービスの実行ファイルのパスを指すのではなく、バッチファイルを指すようにします。バッチファイルの中でワーキングディレクトリを設定し、サービスを起動するコマンドを記述します。

例:

``` batch コードをコピーする
@echo off
cd /d "C:\Your\Desired\Working\Directory"
start "" "YourServiceExecutable.exe"
``` 
これをMyService.batとして保存し、サービスを登録する際にこのバッチファイルを指します。

``` shell コードをコピーする
sc create MyService binPath= "C:\path\to\MyService.bat"
``` 
サービスのコード内でワーキングディレクトリを設定する: サービスの実行ファイル内でEnvironment.CurrentDirectoryを設定します。

``` csharp コードをコピーする
Environment.CurrentDirectory = @"C:\Your\Desired\Working\Directory";
``` 
サービスのレジストリを手動で編集する: サービスが登録された後に、レジストリを編集してワーキングディレクトリを設定することもできますが、これはあまり推奨される方法ではありません。

実行ファイルが配置されているフォルダをワーキングディレクトリとして設定するには、AppDomain.CurrentDomain.BaseDirectoryを使用して実行ファイルのディレクトリを取得し、そのディレクトリをEnvironment.CurrentDirectoryに設定します。以下にそのコード例を示します。

``` csharp コードをコピーする
using System;

class Program
{
    static void Main()
    {
        // 実行ファイルが配置されているフォルダを取得
        string executableDirectory = AppDomain.CurrentDomain.BaseDirectory;
        
        // そのフォルダをワーキングディレクトリに設定
        Environment.CurrentDirectory = executableDirectory;

        // 現在のワーキングディレクトリを確認
        Console.WriteLine("Current Working Directory: " + Environment.CurrentDirectory);

        // ここにワーキングディレクトリを利用するコードを追加
    }
}
``` 
