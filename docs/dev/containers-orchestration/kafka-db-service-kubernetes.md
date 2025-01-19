---
layout: default
title: ".NET 8 で Kafka メッセージを読み取り、DB へ登録するサービスを Kubernetes 上で運用する方法"
category: "Containers Orchestration"
---

# .NET 8 で Kafka メッセージを読み取り、DB へ登録するサービスを Kubernetes 上で運用する方法
はじめに
.NET 8 では、Startup.cs が廃止され、アプリケーション設定はすべて Program.cs に統一されました。本記事では、Kafka からメッセージを受信し、Dapper を使用してストアドプロシージャを介してデータベースに登録するサービスを .NET 8 で構築し、Kubernetes 上で運用する方法を解説します。さらに、ポート設定やヘルスチェックの実装についても紹介します。

## 概要
このサービスは、以下の 2 つのコンポーネントで構成されます。

Kafka 消費者サービス: Kafka からメッセージを受信し、それを一時的に BlockingCollection に格納します。
DB 更新サービス: BlockingCollection からメッセージを取り出し、Dapper を使用してデータベースに登録します。
さらに、サービスはポート 80 でアプリケーションをリッスンし、ポート 8080 でヘルスチェックを提供します。

## 手順
1. Kafka 消費者サービスの実装
まず、Kafka からメッセージを受信するサービスを実装します。ここでは、Confluent.Kafka を使用します。

```csharp コードをコピーする
public class KafkaConsumerService : IHostedService
{
    private readonly ILogger<KafkaConsumerService> _logger;
    private readonly BlockingCollection<string> _messageQueue;
    private readonly string _topic = "my-topic";
    private readonly string _bootstrapServers = "localhost:9092";
    private IConsumer<Ignore, string> _consumer;
    public bool IsReady { get; private set; } = false;

    public KafkaConsumerService(ILogger<KafkaConsumerService> logger, BlockingCollection<string> messageQueue)
    {
        _logger = logger;
        _messageQueue = messageQueue;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        var config = new ConsumerConfig
        {
            GroupId = "test-consumer-group",
            BootstrapServers = _bootstrapServers,
            AutoOffsetReset = AutoOffsetReset.Earliest
        };

        _consumer = new ConsumerBuilder<Ignore, string>(config).Build();
        _consumer.Subscribe(_topic);

        Task.Run(() => ConsumeMessages(cancellationToken), cancellationToken);
        IsReady = true;

        return Task.CompletedTask;
    }

    private void ConsumeMessages(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var consumeResult = _consumer.Consume(cancellationToken);
                var message = consumeResult.Message.Value;

                _messageQueue.Add(message, cancellationToken);
                _logger.LogInformation($"Message received from Kafka: {message}");
            }
            catch (ConsumeException e)
            {
                _logger.LogError($"Error consuming Kafka message: {e.Error.Reason}");
            }
        }
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _consumer.Close();
        _messageQueue.CompleteAdding();
        return Task.CompletedTask;
    }
}
```
2. DB 更新サービスの実装
次に、BlockingCollection からメッセージを取得し、Dapper を使ってストアドプロシージャ経由でデータベースに登録するサービスを実装します。

```csharp コードをコピーする
public class DbUpdateService : IHostedService
{
    private readonly ILogger<DbUpdateService> _logger;
    private readonly BlockingCollection<string> _messageQueue;
    private readonly string _connectionString;
    public bool IsReady { get; private set; } = false;

    public DbUpdateService(ILogger<DbUpdateService> logger, BlockingCollection<string> messageQueue, string connectionString)
    {
        _logger = logger;
        _messageQueue = messageQueue;
        _connectionString = connectionString;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        Task.Run(() => ProcessMessages(cancellationToken), cancellationToken);
        IsReady = true;
        return Task.CompletedTask;
    }

    private async Task ProcessMessages(CancellationToken cancellationToken)
    {
        foreach (var message in _messageQueue.GetConsumingEnumerable(cancellationToken))
        {
            try
            {
                await SaveMessageToDatabase(message);
                _logger.LogInformation($"Message processed and saved to DB: {message}");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error saving message to DB: {ex.Message}");
            }
        }
    }

    private async Task SaveMessageToDatabase(string message)
    {
        using (IDbConnection dbConnection = new SqlConnection(_connectionString))
        {
            var parameters = new DynamicParameters();
            parameters.Add("@Message", message);
            parameters.Add("@ReceivedAt", DateTime.Now);

            await dbConnection.ExecuteAsync("InsertMessageLog", parameters, commandType: CommandType.StoredProcedure);
        }
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
```
3. ポート設定とヘルスチェック
.NET 8 では、Startup.cs を使わず、すべての設定を Program.cs に統一します。ここでは、ポート 80 でアプリケーションを、ポート 8080 でヘルスチェックをリッスンするように設定します。

```csharp コードをコピーする
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
                // BlockingCollection を Singleton で登録
                services.AddSingleton<BlockingCollection<string>>();
                
                // Kafka 消費者サービスと DB 更新サービスを登録
                services.AddHostedService<KafkaConsumerService>();
                services.AddHostedService<DbUpdateService>(provider =>
                    new DbUpdateService(
                        provider.GetRequiredService<ILogger<DbUpdateService>>(),
                        provider.GetRequiredService<BlockingCollection<string>>(),
                        "YourConnectionStringHere"));
                
                // ヘルスチェックの登録
                services.AddHealthChecks()
                    .AddCheck<KafkaHealthCheck>("kafka")
                    .AddCheck<DatabaseHealthCheck>("database");

            })
            .ConfigureWebHostDefaults(webBuilder =>
            {
                // ポート 80 でアプリケーション、8080 でヘルスチェックをリッスン
                webBuilder.UseUrls("http://0.0.0.0:80", "http://0.0.0.0:8080");

                // ヘルスチェックエンドポイントの設定
                webBuilder.Configure(app =>
                {
                    app.UseRouting();

                    app.UseEndpoints(endpoints =>
                    {
                        endpoints.MapHealthChecks("/health");
                    });
                });
            });
}
```
4. Kubernetes デプロイメント YAML
最後に、Kubernetes 上でこのサービスを実行するためのデプロイメント設定ファイルを作成します。

```yaml コードをコピーする
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-consumer-deployment
  labels:
    app: kafka-consumer
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kafka-consumer
  template:
    metadata:
      labels:
        app: kafka-consumer
    spec:
      containers:
      - name: kafka-consumer
        image: your-registry/your-kafka-consumer:latest
        ports:
        - containerPort: 80   # アプリケーション用ポート
        - containerPort: 8080  # ヘルスチェック用ポート
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        env:
        - name: KAFKA_BOOTSTRAP_SERVERS
          value: "your-kafka-bootstrap-servers"
        - name: CONNECTION_STRING
          value: "your-database-connection-string"

```
5. Dockerfile
アプリケーションをコンテナ化するための Dockerfile も準備します。

```dockerfile コードをコピーする
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80  # アプリケーション用ポート
EXPOSE 8080  # ヘルスチェック用ポート

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["YourProject.csproj", "./"]
RUN dotnet restore "./YourProject.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "YourProject.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "YourProject.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "YourProject.dll"]
```
