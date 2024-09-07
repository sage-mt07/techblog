# 【C#】SqlCommandにミリ秒単位でのタイムアウトを設定する拡張メソッド

C#でSQL Serverにアクセスする際、SqlCommandのデフォルトのCommandTimeoutプロパティは秒単位での設定しかサポートしていません。しかし、システム要件やAPI要件によっては、より短いミリ秒単位でのタイムアウト制御が必要な場合があります。この記事では、SqlCommandに対してミリ秒単位のタイムアウトを設定するための拡張メソッドを作成し、簡単に再利用できる形で解説します。

# 課題：CommandTimeoutの限界

通常、SqlCommandは以下のように秒単位でタイムアウトを設定します。

```csharp コードをコピーする
command.CommandTimeout = 2; // 2秒のタイムアウト
```
しかし、例えば500ミリ秒（0.5秒）のタイムアウトを設定することは、CommandTimeoutプロパティだけでは実現できません。そこで、拡張メソッドを使い、500ミリ秒などのタイムアウト処理を簡単に実装できるようにしましょう。

# 解決策：拡張メソッドによるタイムアウト制御
ここでは、SqlCommandにミリ秒単位のタイムアウトを適用できるように拡張メソッドを作成します。この方法では、タスクのタイムアウト制御をTask.DelayやCancellationTokenを使って実現します。

SqlCommandExtensions クラスの実装
まず、SqlCommandに対してタイムアウト処理を行う拡張メソッド ExecuteWithTimeoutAsync を作成します。

``` csharp コードをコピーする
using System;
using System.Data.SqlClient;
using System.Threading;
using System.Threading.Tasks;

public static class SqlCommandExtensions
{
    /// <summary>
    /// SQLコマンドを指定したミリ秒のタイムアウトで実行します。
    /// </summary>
    /// <param name="command">実行するSQLコマンド</param>
    /// <param name="millisecondsTimeout">タイムアウトまでの時間（ミリ秒）</param>
    /// <returns>タスクの結果</returns>
    public static async Task<int> ExecuteWithTimeoutAsync(this SqlCommand command, int millisecondsTimeout)
    {
        using (var cts = new CancellationTokenSource())
        {
            // タイムアウトを設定
            cts.CancelAfter(millisecondsTimeout);
            
            var sqlTask = command.ExecuteNonQueryAsync(cts.Token);
            var delayTask = Task.Delay(millisecondsTimeout);
            
            var completedTask = await Task.WhenAny(sqlTask, delayTask);

            // タイムアウトが発生した場合
            if (completedTask == delayTask)
            {
                throw new TimeoutException($"SQL command timed out after {millisecondsTimeout} ms.");
            }
            
            // SQLコマンドが完了した場合
            return await sqlTask;
        }
    }
}
```
## この拡張メソッドのポイント

- CancellationTokenSourceを使用: タイムアウトを制御するために、CancellationTokenSourceを使ってタイムアウトが発生した場合にタスクをキャンセルします。
- Task.WhenAnyで非同期タスクの完了を待つ: SQLコマンドの実行とタイムアウトのどちらが先に完了するかを判定します。
- タイムアウト時にTimeoutExceptionをスロー: 指定された時間内に完了しない場合は、タイムアウトとして処理されます。

## 使用例
拡張メソッドを作成したら、以下のように簡単に500ミリ秒のタイムアウトを設定してSQLコマンドを実行することができます。

```csharp
コードをコピーする
using System;
using System.Data.SqlClient;
using System.Threading.Tasks;

class Program
{
    static async Task Main(string[] args)
    {
        string connectionString = "your_connection_string_here";

        using (SqlConnection connection = new SqlConnection(connectionString))
        {
            await connection.OpenAsync();

            using (SqlCommand command = new SqlCommand("SELECT * FROM SomeTable", connection))
            {
                try
                {
                    // 500ミリ秒のタイムアウトでSQLコマンドを実行
                    int result = await command.ExecuteWithTimeoutAsync(500);
                    Console.WriteLine($"SQLコマンドが完了しました。結果: {result}");
                }
                catch (TimeoutException ex)
                {
                    Console.WriteLine(ex.Message);
                }
                catch (SqlException ex)
                {
                    Console.WriteLine($"SQLエラー: {ex.Message}");
                }
            }
        }
    }
}
```

# 実行結果

500ミリ秒以内にSQLクエリが完了すれば、正常に結果が返されます。一方で、500ミリ秒を超えると、次のようなメッセージが表示されます。

```bash コードをコピーする
SQL command timed out after 500 ms.
```

# 拡張メソッドの利点

このように拡張メソッドとしてまとめることで、SqlCommand にミリ秒単位のタイムアウトを簡単に設定でき、再利用性が向上します。また、秒単位での制約を超え、より精密なタイムアウト制御が可能になるため、パフォーマンスチューニングや応答性が重要なシステムに役立ちます。