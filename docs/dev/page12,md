# SQL Server 接続プールの監視と警告・エラーログの実装方法

データベース接続を効率よく管理するために、SqlConnection では接続プールが使用されます。しかし、並列処理の負荷が高い場合や長時間接続を占有する場合、接続プールが枯渇する可能性があります。この記事では、接続プールの問題とその解決策について解説します。

# 問題: SQL Server の接続プールが枯渇するリスク
SQL Server へのアクセスが集中すると、接続プールに設定された Max Pool Size を超える接続要求が発生し、次のような問題が発生する可能性があります。

遅延発生: 接続プールが枯渇すると、他のリクエストが接続を待機するため、アプリケーションのレスポンスが遅れる可能性があります。
接続失敗: Max Pool Size を超えたリクエストは接続が拒否され、SQL Server との通信に失敗します。

# 対策: 接続プールの監視とログ出力
SqlConnectionPoolManager クラスを使って、SQL Server の接続プールの状態を監視し、接続が枯渇しそうな場合に警告やエラーログを出力する方法を紹介します。

監視するポイント
アクティブな接続数: 現在使用中の接続数を追跡し、接続プールが満杯に近づいた場合に警告を出す。
未使用の接続数: プール内に残っている未使用の接続数を計算し、接続が枯渇した場合にはエラーログを出力する。

実装方法
``` csharp コードをコピーする
public class SqlConnectionPoolManager
{
    private readonly string _connectionString;
    private readonly int _maxPoolSize;
    private static int _activeConnections = 0;

    public SqlConnectionPoolManager(string connectionString)
    {
        _connectionString = connectionString;
        _maxPoolSize = GetMaxPoolSizeFromConnectionString(_connectionString);
    }

    public SqlConnection CreateTrackedConnection()
    {
        var connection = new SqlConnection(_connectionString);
        connection.StateChange += (sender, e) =>
        {
            if (e.CurrentState == System.Data.ConnectionState.Open)
                Interlocked.Increment(ref _activeConnections);
            if (e.CurrentState == System.Data.ConnectionState.Closed)
                Interlocked.Decrement(ref _activeConnections);

            // 接続プールの残りをチェック
            CheckConnectionPoolStatus();
        };

        return connection;
    }

    private int GetMaxPoolSizeFromConnectionString(string connectionString)
    {
        var builder = new SqlConnectionStringBuilder(connectionString);
        return builder.MaxPoolSize; // 指定されていない場合、デフォルト値は 100
    }

    private void CheckConnectionPoolStatus()
    {
        int freeConnections = _maxPoolSize - _activeConnections;

        if (freeConnections == 0)
        {
            LogError("Error: No available connections in the pool.");
        }
        else if (freeConnections <= _maxPoolSize * 0.1) // 残り10%未満の場合
        {
            LogWarning($"Warning: Low connection pool resources. Only {freeConnections} connections available.");
        }
    }

    private void LogWarning(string message)
    {
        Console.WriteLine($"[WARNING] {message}");
    }

    private void LogError(string message)
    {
        Console.WriteLine($"[ERROR] {message}");
    }
}
```

# 利用シナリオ
例えば、アプリケーションが SQL Server に対して多数の並列リクエストを送信する場合、次のようなロジックを実装することで、接続プールの枯渇を防ぐことができます。

Max Pool Size を動的に設定し、その値を監視します。
接続プールが 90% 使用されているときに警告ログを出力します。
接続プールが枯渇したときにエラーログを出力します。
この方法によって、接続プールの状態をリアルタイムに把握し、アプリケーションのパフォーマンス低下を防止することが可能です。
