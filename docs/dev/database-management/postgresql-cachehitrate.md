---
layout: default
title: "Azure App Service WebJobでPostgreSQLのキャッシュヒット率をAzure Monitorに送信する方法"
category: "database management"
---
# Azure App Service WebJobでPostgreSQLのキャッシュヒット率をAzure Monitorに送信する方法
Azure環境でPostgreSQLを使用している場合、パフォーマンス監視は非常に重要です。特にキャッシュの有効性を監視することは、クエリの効率を測定する上で役立ちます。本記事では、Azure App Service WebJobを利用して、PostgreSQLからキャッシュヒット率を定期的に取得し、それをAzure Monitorにカスタムメトリクスとして送信する方法について解説します。

## 前提条件
- PostgreSQL: PostgreSQLインスタンスがAzure上またはローカルにセットアップされていること。
- Azure App Service: WebJobをデプロイするためのAzure App Serviceが準備されていること。
- Azure Monitor: メトリクスを送信するAzure Monitorが設定されていること。
## ステップ1: PostgreSQLからキャッシュヒット率を取得する
まず、PostgreSQLからキャッシュヒット率を取得する方法を説明します。PostgreSQLは、pg_stat_databaseビューを提供しており、そこからデータベースごとのキャッシュヒット率を計算できます。

次のSQLクエリで、キャッシュヒット率を取得できます:

```sql コードをコピーする
SELECT datname, 
       blks_hit::float / (blks_hit + blks_read) * 100 AS cache_hit_ratio 
FROM pg_stat_database 
WHERE datname = '<your_database_name>';
```
このクエリにより、データベース名ごとにキャッシュヒット率（%）が計算されます。

## ステップ2: WebJobを設定する
次に、Azure App Service WebJobを作成し、PostgreSQLのキャッシュヒット率を取得してAzure Monitorに送信するコードを作成します。

必要なNuGetパッケージ
まず、必要なライブラリをインストールします。PostgreSQLとAzure Monitorのクライアントライブラリを使用します。

```bash コードをコピーする
dotnet add package Npgsql
dotnet add package Azure.Monitor.Query
```
コード例
以下は、PostgreSQLからキャッシュヒット率を取得し、Azure Monitorにメトリクスを送信するWebJobのコードです。
Program.cs
```csharp コードをコピーする
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

HostApplicationBuilder builder = Host.CreateApplicationBuilder(args);

// HttpClientのDI設定
builder.Services.AddHttpClient();

// Azure MonitorのMetricsClientを設定
builder.Services.AddSingleton<MetricsClient>(sp =>
{
    var credential = new DefaultAzureCredential();
    return new MetricsClient(credential);
});

// MyWorkerをサービスとして登録
builder.Services.AddHostedService<MyWorker>();

var app = builder.Build();
app.Run();


```

MyWorker.cs
```csharp コードをコピーする
using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Npgsql;
using Azure.Monitor.Query;
using Azure.Identity;

public class MyWorker : BackgroundService
{
    private readonly int _executionInterval;
    private readonly string _connectionString;
    private string _subscriptionId;
    private string _resourceGroupName;
    private readonly string _resourceUri;
    private readonly ILogger<MyWorker> _logger;

    public MyWorker(int executionInterval, string connectionString, ILogger<MyWorker> logger)
    {
        _executionInterval = executionInterval;
        _connectionString = connectionString;
        _logger = logger;

        // Initialize resource identifiers by fetching metadata from IMDS
        var metadata = GetAzureInstanceMetadataAsync().GetAwaiter().GetResult();
        _subscriptionId = metadata.subscriptionId;
        _resourceGroupName = metadata.resourceGroupName;

        // PostgreSQLのサーバー名を接続文字列から抽出し、リソースURIを構築
        var postgresqlServerName = ExtractServerNameFromConnectionString(_connectionString);
        if (!string.IsNullOrEmpty(postgresqlServerName))
        {
            _resourceUri = $"/subscriptions/{_subscriptionId}/resourceGroups/{_resourceGroupName}/providers/Microsoft.DBforPostgreSQL/servers/{postgresqlServerName}";
        }
        else
        {
            _logger.LogError("PostgreSQL server name could not be extracted from the connection string.");
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // PostgreSQLからキャッシュヒット率を取得
                double cacheHitRate = await GetPostgreSqlCacheHitRate(_connectionString);
                _logger.LogInformation($"Cache Hit Rate: {cacheHitRate}%");

                // キャッシュヒット率をAzure Monitorに送信
                await SendMetricToAzureMonitor(cacheHitRate, _resourceUri);

                // 次の実行まで指定秒数待機
                _logger.LogInformation($"Waiting for {_executionInterval} seconds before next execution.");
                await Task.Delay(_executionInterval * 1000, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An error occurred during execution.");
            }
        }
    }

    private async Task<double> GetPostgreSqlCacheHitRate(string connectionString)
    {
        double cacheHitRate = 0;
        using (var conn = new NpgsqlConnection(connectionString))
        {
            await conn.OpenAsync();

            string query = @"
                SELECT blks_hit::float / (blks_hit + blks_read) * 100 AS cache_hit_ratio
                FROM pg_stat_database
                WHERE datname = current_database()";

            using (var cmd = new NpgsqlCommand(query, conn))
            {
                var result = await cmd.ExecuteScalarAsync();
                if (result != null && result != DBNull.Value)
                {
                    cacheHitRate = Convert.ToDouble(result);
                }
            }
        }
        return cacheHitRate;
    }

    private async Task SendMetricToAzureMonitor(double cacheHitRate, string resourceUri)
    {
        var credential = new DefaultAzureCredential();
        var monitorClient = new MetricsClient(credential);

        var metric = new MetricQueryDefinition(
            "CustomMetrics",
            new[]
            {
                new MetricQueryTimeSeriesData(
                    "CacheHitRate",
                    new MetricQueryTimeSeriesDataPoint
                    {
                        Average = cacheHitRate
                    }
                )
            }
        );

        await monitorClient.SendMetricsAsync(resourceUri, metric);
    }

    private string ExtractServerNameFromConnectionString(string connectionString)
    {
        var match = System.Text.RegularExpressions.Regex.Match(connectionString, @"Host=([\w\d\-\.]+)");
        return match.Success ? match.Groups[1].Value : null;
    }

    private async Task<(string subscriptionId, string resourceGroupName)> GetAzureInstanceMetadataAsync()
    {
        using (HttpClient client = new HttpClient())
        {
            client.DefaultRequestHeaders.Add("Metadata", "true");

            var response = await client.GetAsync("http://169.254.169.254/metadata/instance?api-version=2021-02-01");

            if (response.IsSuccessStatusCode)
            {
                var json = await response.Content.ReadAsStringAsync();
                var document = JsonDocument.Parse(json);

                var subscriptionId = document.RootElement.GetProperty("compute").GetProperty("subscriptionId").GetString();
                var resourceGroupName = document.RootElement.GetProperty("compute").GetProperty("resourceGroupName").GetString();

                return (subscriptionId, resourceGroupName);
            }
            else
            {
                _logger.LogError("Failed to retrieve Azure instance metadata.");
                throw new InvalidOperationException("Unable to fetch metadata from Azure Instance Metadata Service.");
            }
        }
    }
}

```

## ステップ3: 環境変数の設定
WebJobは、実行間隔や接続情報を環境変数から取得します。ローカルやAzureポータルで環境変数を設定することで、動作をカスタマイズできます。

ローカル環境での設定
launchSettings.jsonを使用して、ローカルで環境変数を設定できます。

```json コードをコピーする
{
  "ExecutionIntervalSeconds": 1,
  "PostgreSql": {
    "ServerName": "my-postgresql-server",
    "DatabaseName": "mydatabase",
    "Username": "myuser",
    "Password": "mypassword"
  }
}


```
Azure App Serviceでの設定

AzureポータルのApp Serviceの「構成」セクションから、必要な環境変数を設定します。

1. ExecutionIntervalSeconds: 実行間隔（秒）
1. POSTGRESQL__ServerName: PostgreSQLの接続文字列
1. POSTGRESQL__DatabaseName: PostgreSQLの接続文字列
1. POSTGRESQL__Username: PostgreSQLの接続文字列
1. POSTGRESQL__Password: PostgreSQLの接続文字列

## kusto
kustoを使用する場合、以下のクエリを発行します。
```
AzureMetrics
| where Resource == "MyPostgreSQLServer"
| where MetricName == "CustomMetrics"
| where TimeGenerated >= ago(1d)
| project TimeGenerated, Average
| order by TimeGenerated desc
```
