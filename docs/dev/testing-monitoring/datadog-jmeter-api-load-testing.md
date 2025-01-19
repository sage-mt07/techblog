---
layout: default
title: "DatadogとJMeterを活用したAPI負荷テストのログ収集とシナリオ作成"
category: "test monitoring"
---
# DatadogとJMeterを活用したAPI負荷テストのログ収集とシナリオ作成

APIのパフォーマンステストは、ユーザーの実際の動作を再現することが鍵となります。本記事では、.NET 8とKubernetes上でホストされたREST APIのリクエストとレスポンスをDatadogにログとして記録し、JMeterを用いた負荷テストシナリオの作成方法について解説します。

## 1. リクエストとレスポンスのログをDatadogに出力
まず、すべてのリクエストとレスポンスをDatadogにログとして送信し、それらのデータをもとにJMeterでの負荷テストシナリオを作成します。ASP.NET Coreでミドルウェアを使用して、リクエストおよびレスポンスの情報をキャプチャし、セッションIDやユーザーIDをタグとしてログに含めます。

ミドルウェアの実装
以下のコードは、リクエストの内容（URL、メソッド、クエリパラメータ、ボディ）およびレスポンスの内容（ステータスコード、ボディ）をログとして出力します。

```csharp
コードをコピーする
public class RequestResponseLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestResponseLoggingMiddleware> _logger;

    public RequestResponseLoggingMiddleware(RequestDelegate next, ILogger<RequestResponseLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task Invoke(HttpContext context)
    {
        var sessionId = context.Session.Id;
        var userId = context.User.Identity.IsAuthenticated ? context.User.Identity.Name : "Anonymous";
        var request = context.Request;

        // リクエストの記録
        context.Request.EnableBuffering();
        var requestBody = await new StreamReader(request.Body).ReadToEndAsync();
        context.Request.Body.Position = 0;

        using (_logger.BeginScope(new Dictionary<string, object>
        {
            { "dd.session_id", sessionId },
            { "dd.user_id", userId }
        }))
        {
            _logger.LogInformation("Request: {Method} {Url}, Query: {Query}, Body: {Body}",
                request.Method, request.Path, request.QueryString, requestBody);

            // レスポンスのキャプチャ
            var originalBodyStream = context.Response.Body;
            using var responseBody = new MemoryStream();
            context.Response.Body = responseBody;

            await _next(context);

            context.Response.Body.Seek(0, SeekOrigin.Begin);
            var responseText = await new StreamReader(context.Response.Body).ReadToEndAsync();
            context.Response.Body.Seek(0, SeekOrigin.Begin);

            _logger.LogInformation("Response: {StatusCode}, Body: {Body}", context.Response.StatusCode, responseText);

            await responseBody.CopyToAsync(originalBodyStream);
        }
    }
}
```
このミドルウェアにより、Datadogに対してリクエストおよびレスポンスのデータが一貫して送信されます。また、セッションIDやユーザーIDをタグとしてログに含めることで、ユーザーごとのリクエストやレスポンスをDatadogで簡単にフィルタリングすることが可能です。

## 2. Program.csでのミドルウェア設定
このミドルウェアをアプリケーションで有効にするためには、Program.csで登録します。以下はその設定例です。

Program.cs の設定例
```csharp
コードをコピーする
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);

// ロギング設定 (必要に応じてカスタマイズ)
builder.Services.AddLogging(logging =>
{
    logging.ClearProviders();
    logging.AddConsole(); // コンソールログ出力
    logging.AddDatadogLogger(options => // Datadogへのログ出力 (仮定)
    {
        options.Service = "my-app-service";
        options.ApiKey = "YOUR_DATADOG_API_KEY";
    });
});

var app = builder.Build();

// ミドルウェアを追加
app.UseMiddleware<RequestResponseLoggingMiddleware>();

// 他のミドルウェアやエンドポイント
app.UseRouting();
app.UseAuthentication(); // 認証が必要な場合
app.UseAuthorization();
app.MapControllers(); // コントローラーのエンドポイントをマッピング

app.Run();
```
ロギング設定：

AddLogging でロギングを設定し、Datadogへの出力を追加します。
AddDatadogLogger には、Datadog APIキーやサービス名を指定します。
ミドルウェアの登録：

app.UseMiddleware<RequestResponseLoggingMiddleware>(); でリクエストとレスポンスのロギングを有効化します。
他のミドルウェア：

ルーティング、認証、承認の設定を行い、必要なエンドポイントが正しく処理されるようにします。
## 3. Datadogでのフィルタリング
Datadogに送信されたログは、タグを使用してフィルタリングすることができます。例えば、セッションIDやユーザーIDで特定のリクエストやレスポンスを抽出する場合、次のようなクエリをDatadogで実行します。

フィルタリングクエリ例
```datadog
コードをコピーする
dd.session_id:abcd1234 AND dd.user_id:john_doe
```
このクエリにより、セッションID abcd1234 でユーザー john_doe が行ったすべてのリクエストやレスポンスを簡単に抽出できます。

## 4. JMeterでの負荷テストシナリオ作成
DatadogでフィルタリングしたログをCSVやJSON形式でエクスポートし、JMeterでのテストシナリオ作成に活用します。エクスポートしたデータは、JMeterの CSV Data Set Config を使用して負荷テストに利用できます。

JMeterのCSV Data Set Config例
```bash
コードをコピーする
Thread Group
  |-- CSV Data Set Config (ファイルパス: datadog_export.csv)
  |-- HTTP Request
       |-- Path: ${Url}
       |-- Method: ${Method}
       |-- Body Data: ${Body}
```
Datadogから抽出したリクエスト情報を元に、JMeterでAPIテストシナリオを自動的に生成できます。
