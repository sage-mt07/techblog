# BackgroundServiceを継承せずに.NET 8でIHostedServiceを実装する
このブログでは、.NET 8でBackgroundServiceを継承せずにIHostedServiceを使ってバックグラウンドタスクを実装する方法について解説します。BackgroundServiceを使用しないことで、サービスのライフサイクルに対する柔軟な制御が可能になり、特定のニーズに応じたカスタマイズができます。

なぜBackgroundServiceを避けるのか？
BackgroundServiceは便利なベースクラスですが、ExecuteAsyncメソッドが常に繰り返し実行されるというパターンを取るため、以下のような場面では適していない場合があります。

- 初期化処理をメインの処理を始める前に行いたい場合。
- メインの処理を自分で管理し、任意のタイミングで実行したい場合。
- 開始・停止フェーズで複雑なリソース管理が必要な場合。
- キャンセルや正常終了の制御をカスタマイズしたい場合。
このような状況では、IHostedServiceを直接実装することで、よりきめ細かな制御が可能になります。

IHostedServiceの使用方法
次に、IHostedServiceを直接実装する例を紹介します。このサービスは以下の流れで動作します。

- 初期化処理: サービス開始時に初期化処理を行います。
- メイン処理: 初期化が完了した後に、メイン処理を開始します。
- 正常終了: サービス終了時にメイン処理をキャンセルし、リソースを解放します。

実装例
```csharp コードをコピーする
using Microsoft.Extensions.Hosting;
using System;
using System.Threading;
using System.Threading.Tasks;

public class CustomHostedService : IHostedService, IDisposable
{
    private Task _mainTask;
    private CancellationTokenSource _cts;

    // StartAsyncはアプリケーションの開始時に呼ばれます
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        Console.WriteLine("Custom Hosted Service starting...");

        // 初期化処理をここで実行
        await InitializeAsync();

        // 初期化が終わったらメイン処理を開始
        _cts = new CancellationTokenSource();
        _mainTask = MainProcessAsync(_cts.Token);

        Console.WriteLine("Initialization completed. Main process started.");
    }

    // 初期化処理
    private async Task InitializeAsync()
    {
        Console.WriteLine("Initializing...");
        // 例えば、DB接続や設定読み込みなどをここで行う
        await Task.Delay(3000); // 3秒間の初期化をシミュレーション
        Console.WriteLine("Initialization done.");
    }

    // メイン処理
    private async Task MainProcessAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            // メインの業務ロジックをここで実行
            Console.WriteLine($"Main process running at {DateTime.Now}");

            // 一定時間ごとに実行
            await Task.Delay(5000, cancellationToken); // 5秒ごとに実行
        }
    }

    // StopAsyncはアプリケーションの停止時に呼ばれます
    public async Task StopAsync(CancellationToken cancellationToken)
    {
        Console.WriteLine("Custom Hosted Service stopping...");

        if (_mainTask != null)
        {
            // メイン処理をキャンセル
            _cts.Cancel();

            // メイン処理が終了するまで待機
            await Task.WhenAny(_mainTask, Task.Delay(Timeout.Infinite, cancellationToken));
        }
    }

    // サービスが終了した際にリソースを解放
    public void Dispose()
    {
        _cts?.Cancel();
        _cts?.Dispose();
    }
}
```
Program.csでの登録

このカスタムホストサービスを利用するためには、Program.csでDI（依存性注入）コンテナに登録する必要があります。

```csharp コードをコピーする
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

public class Program
{
    public static void Main(string[] args)
    {
        CreateHostBuilder(args).Build().Run();
    }

    public static IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args)
            .ConfigureServices((hostContext, services) =>
            {
                // カスタムホストサービスを登録
                services.AddHostedService<CustomHostedService>();
            });
}
```
実装の流れ
1. StartAsync: サービスの開始時に呼ばれ、初期化処理（InitializeAsync）が実行されます。初期化が完了すると、MainProcessAsyncでメイン処理が開始されます。
1. InitializeAsync: サービス開始時に行いたい処理（設定の読み込みや接続など）を非同期で実行します。
1. MainProcessAsync: メインの処理を実行するループです。CancellationTokenでキャンセルがリクエストされるまで、定期的に処理を実行します。
1. StopAsync: サービス停止時に呼ばれ、メイン処理をキャンセルし、すべての処理が終了するまで待機します。
1. Dispose: サービス終了時に必要なリソースを解放します。
