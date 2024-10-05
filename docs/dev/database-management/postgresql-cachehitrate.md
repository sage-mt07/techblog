# ブログタイトル: Azure App Service WebJobでPostgreSQLのキャッシュヒット率をAzure Monitorに送信する方法
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

```csharp コードをコピーする
using System;
using System.Threading;
using System.Threading.Tasks;
using Npgsql;
using Azure.Monitor.Query;
using Azure.Identity;

namespace WebJobExample
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // 環境変数から実行間隔を取得
            string intervalEnv = Environment.GetEnvironmentVariable("EXECUTION_INTERVAL_SECONDS");
            int executionInterval = string.IsNullOrEmpty(intervalEnv) ? 60 : int.Parse(intervalEnv);  // デフォルトは60秒

            Console.WriteLine($"Execution interval set to {executionInterval} seconds.");

            // PostgreSQL接続情報（環境変数から取得）
            string connectionString = Environment.GetEnvironmentVariable("POSTGRESQL_CONNECTION_STRING");
            string databaseName = Environment.GetEnvironmentVariable("POSTGRESQL_DATABASE_NAME");

            // WebJobの無限ループ
            while (true)
            {
                try
                {
                    // PostgreSQLからキャッシュヒット率を取得
                    double cacheHitRate = await GetPostgreSqlCacheHitRate(connectionString, databaseName);

                    Console.WriteLine($"Cache Hit Rate: {cacheHitRate}%");

                    // キャッシュヒット率をAzure Monitorに送信
                    await SendMetricToAzureMonitor(cacheHitRate);

                    // 次の実行まで指定秒数待機
                    Console.WriteLine($"Waiting for {executionInterval} seconds before next execution.");
                    Thread.Sleep(executionInterval * 1000);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"An error occurred: {ex.Message}");
                }
            }
        }

        // PostgreSQLからキャッシュヒット率を取得する
        static async Task<double> GetPostgreSqlCacheHitRate(string connectionString, string databaseName)
        {
            double cacheHitRate = 0;

            using (var conn = new NpgsqlConnection(connectionString))
            {
                await conn.OpenAsync();
                
                string query = $@"
                    SELECT blks_hit::float / (blks_hit + blks_read) * 100 AS cache_hit_ratio
                    FROM pg_stat_database
                    WHERE datname = @databaseName";

                using (var cmd = new NpgsqlCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("databaseName", databaseName);

                    var result = await cmd.ExecuteScalarAsync();
                    if (result != null && result != DBNull.Value)
                    {
                        cacheHitRate = Convert.ToDouble(result);
                    }
                }
            }

            return cacheHitRate;
        }

        // キャッシュヒット率をAzure Monitorに送信する
        static async Task SendMetricToAzureMonitor(double cacheHitRate)
        {
            var credential = new DefaultAzureCredential();

            var monitorClient = new MetricsClient(credential);
            var resourceUri = "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.Web/sites/<app-service-name>";

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

            Console.WriteLine("Metric sent to Azure Monitor.");
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
  "profiles": {
    "WebJobExample": {
      "commandName": "Project",
      "environmentVariables": {
        "EXECUTION_INTERVAL_SECONDS": "60",
        "POSTGRESQL_CONNECTION_STRING": "Host=my_host;Username=my_user;Password=my_password;Database=my_database",
        "POSTGRESQL_DATABASE_NAME": "my_database"
      }
    }
  }
}
```
Azure App Serviceでの設定

AzureポータルのApp Serviceの「構成」セクションから、必要な環境変数を設定します。

1. EXECUTION_INTERVAL_SECONDS: 実行間隔（秒）
1. POSTGRESQL_CONNECTION_STRING: PostgreSQLの接続文字列
1. POSTGRESQL_DATABASE_NAME: データベース名
