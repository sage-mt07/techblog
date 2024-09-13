# .NET 8 WebAPIでAPIごとにタイムアウトを設定する方法

.NET 8でWebAPIを開発する際に、特定のAPIにタイムアウトを設定し、指定された秒数内に処理が完了しなかった場合にタイムアウトエラーを返す方法をご紹介します。本記事では、タイムアウトを簡単に設定できるようにカスタム属性 (Attribute) を使用し、各APIごとに異なるタイムアウト時間を指定する方法を解説します。

タイムアウト設定が必要な理由
APIにタイムアウトを設定することで、バックエンドで時間のかかる処理が発生した際に、クライアントが無限に待つことを防ぐことができます。特に、一定時間以内に応答が得られない場合に、APIが適切に「リクエストタイムアウト」エラーを返すことは、ユーザー体験やシステム全体のパフォーマンス向上に貢献します。

カスタム属性を使ったタイムアウト設定
ここでは、APIごとにタイムアウトを設定するためのカスタム属性TimeoutAttributeを作成し、APIメソッドに適用する方法を解説します。

## ステップ1: TimeoutAttributeクラスの作成
まず、カスタム属性を作成します。この属性では、指定された秒数内にAPIの処理が終わらない場合に、HTTPステータスコード408 (Request Timeout) を返します。

```csharp コードをコピーする
using Microsoft.AspNetCore.Mvc.Filters;
using System.Threading;

public class TimeoutAttribute : Attribute, IAsyncActionFilter
{
    private readonly int _timeoutSeconds;

    public TimeoutAttribute(int timeoutSeconds)
    {
        _timeoutSeconds = timeoutSeconds;
    }

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        using (var cts = new CancellationTokenSource())
        {
            cts.CancelAfter(TimeSpan.FromSeconds(_timeoutSeconds));

            try
            {
                var task = next();
                if (await Task.WhenAny(task, Task.Delay(_timeoutSeconds * 1000, cts.Token)) == task)
                {
                    // アクションがタイムアウトせずに完了した場合
                    await task;
                }
                else
                {
                    // タイムアウト発生時
                    context.HttpContext.Response.StatusCode = StatusCodes.Status408RequestTimeout;
                    await context.HttpContext.Response.WriteAsync("Request timed out.");
                }
            }
            catch (OperationCanceledException) when (cts.Token.IsCancellationRequested)
            {
                context.HttpContext.Response.StatusCode = StatusCodes.Status408RequestTimeout;
                await context.HttpContext.Response.WriteAsync("Request timed out.");
            }
        }
    }
}
```
## ステップ2: コントローラーでのタイムアウト設定
次に、コントローラー内でAPIメソッドに先ほど作成したカスタム属性Timeoutを適用します。これにより、各APIメソッドごとに異なるタイムアウト時間を設定することができます。

```csharp コードをコピーする
[ApiController]
[Route("[controller]")]
public class SampleController : ControllerBase
{
    [HttpGet]
    [Timeout(5)] // 5秒のタイムアウトを設定
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        try
        {
            // 長時間かかる処理の例
            await Task.Delay(10000, cancellationToken);
            return Ok("Operation completed.");
        }
        catch (OperationCanceledException)
        {
            return StatusCode(StatusCodes.Status408RequestTimeout, "Operation timed out.");
        }
    }
}
```
上記のコードでは、[Timeout(5)]という属性を使って、APIの処理時間が5秒を超えた場合にタイムアウトエラーを返すように設定しています。これにより、Getメソッドが5秒以内に完了しない場合、タイムアウト (408 Request Timeout) が発生し、"Request timed out"というメッセージが返されます。