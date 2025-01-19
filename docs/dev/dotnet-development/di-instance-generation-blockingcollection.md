---
layout: default
title: ".NET における DI を使った任意のタイミングでのインスタンス生成と BlockingCollection の共有"
category: "dotnet develop"
---
# .NET における DI を使った任意のタイミングでのインスタンス生成と BlockingCollection の共有

概要
この記事では、.NET の依存関係注入 (DI) を活用し、任意のタイミングでインスタンスを生成する方法と、スレッドセーフな BlockingCollection を共有する方法について紹介します。

通常、.NET の DI ではコンストラクタでサービスを注入し、それに依存してアプリケーションを実行します。しかし、特定のタイミングで動的にインスタンスを生成したい場合には、IServiceProvider を使って DI コンテナからインスタンスを取得することが有効です。

記事の流れ
BlockingCollection を利用したプロデューサー・コンシューマーパターン
IServiceProvider を使って、任意のタイミングでサービスを生成する方法
サンプルコードと実際の動作
応用例
## 1. BlockingCollection とは？
BlockingCollection<T> は、スレッドセーフなデータ構造であり、プロデューサー (データ生成者) とコンシューマー (データ消費者) のパターンにおいて便利です。複数のスレッド間でデータをやり取りしながら、スレッドが競合することなく安全に動作する仕組みを提供します。

プロデューサー・コンシューマーパターン
プロデューサーはデータを作成して BlockingCollection に追加し、コンシューマーは BlockingCollection からデータを取り出して処理します。この動作は並列処理の分野でよく利用されるパターンです。

## 2. IServiceProvider を使った任意のタイミングでのインスタンス生成
通常の DI では、コンストラクタで依存関係が注入されますが、アプリケーションの中で動的に依存関係を解決してインスタンスを生成したいケースもあります。その場合、IServiceProvider を使うと、依存関係を解決してインスタンスを生成できます。

例えば、以下のようにして ProducerWorker や ConsumerWorker のインスタンスを生成して、必要なタイミングで開始することができます。

## 3. サンプルコード
このサンプルでは、BlockingCollection<string> を Singleton として共有し、ProducerWorker でデータを追加し、ConsumerWorker でデータを消費します。また、WorkerManager を使って任意のタイミングでこれらのワーカーを起動します。

### 3.1 ProducerWorker の定義
```csharp コードをコピーする
public class ProducerWorker : BackgroundService
{
    private readonly ILogger<ProducerWorker> _logger;
    private readonly BlockingCollection<string> _collection;

    public ProducerWorker(ILogger<ProducerWorker> logger, BlockingCollection<string> collection)
    {
        _logger = logger;
        _collection = collection;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        int counter = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            string data = $"Data-{counter++}";
            _collection.Add(data);
            _logger.LogInformation($"Produced: {data}");
            await Task.Delay(500, stoppingToken);
        }
    }
}
```
### 3.2 ConsumerWorker の定義
```csharp コードをコピーする
public class ConsumerWorker : BackgroundService
{
    private readonly ILogger<ConsumerWorker> _logger;
    private readonly BlockingCollection<string> _collection;

    public ConsumerWorker(ILogger<ConsumerWorker> logger, BlockingCollection<string> collection)
    {
        _logger = logger;
        _collection = collection;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested && !_collection.IsCompleted)
        {
            try
            {
                string data = _collection.Take(stoppingToken);
                _logger.LogInformation($"Consumed: {data}");
            }
            catch (OperationCanceledException)
            {
                break;
            }
            await Task.Delay(1000, stoppingToken);
        }
    }
}
```
### 3.3 任意のタイミングでワーカーを開始する WorkerManager
```csharp コードをコピーする
public class WorkerManager
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<WorkerManager> _logger;

    public WorkerManager(IServiceProvider serviceProvider, ILogger<WorkerManager> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    public void StartWorkers()
    {
        using (var scope = _serviceProvider.CreateScope())
        {
            var producer = scope.ServiceProvider.GetRequiredService<ProducerWorker>();
            Task.Run(() => producer.StartAsync(CancellationToken.None));

            var consumer = scope.ServiceProvider.GetRequiredService<ConsumerWorker>();
            Task.Run(() => consumer.StartAsync(CancellationToken.None));

            _logger.LogInformation("ProducerWorker と ConsumerWorker が開始されました。");
        }
    }
}
```
### 3.4 Program.cs でのサービス登録
```csharp コードをコピーする
var host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
        services.AddSingleton(new BlockingCollection<string>(boundedCapacity: 10));
        services.AddTransient<ProducerWorker>();
        services.AddTransient<ConsumerWorker>();
        services.AddSingleton<WorkerManager>();
    })
    .Build();

using (var scope = host.Services.CreateScope())
{
    var workerManager = scope.ServiceProvider.GetRequiredService<WorkerManager>();
    workerManager.StartWorkers();
}

await host.RunAsync();
```
実行結果
```csharp コードをコピーする
[INFO] ProducerWorker と ConsumerWorker が開始されました。
[INFO] Produced: Data-0
[INFO] Consumed: Data-0
[INFO] Produced: Data-1
[INFO] Consumed: Data-1
...
```
### 4. 応用例
この方法を応用すれば、任意のタイミングで複数のワーカーやサービスを起動することが可能です。たとえば、特定のイベントが発生したときに新しいワーカーを起動したり、動的にインスタンスを作成して処理を開始することができます。
