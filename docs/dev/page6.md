# 負荷試験のためのログ収集からk6への展開

net8でホストしているREST関する仕組みづくり

##　 ミドルウェアを利用したログ収集とタグ付与

ミドルウェアの概要
ASP.NET Coreのミドルウェアを使用して、各APIリクエストの詳細なログを収集します。ミドルウェアでは、リクエストとレスポンスの情報をキャプチャし、特定のタグを付与してDatadogに送信します。

ミドルウェアの実装例
以下は、ミドルウェアでログを収集し、特定のタグを付与してDatadogに送信する例です。

```
using Microsoft.AspNetCore.Http;
using Serilog;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

public class RequestResponseLoggingMiddleware
{
    private readonly RequestDelegate _next;

    public RequestResponseLoggingMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // JMeterからのリクエストかどうかを判断するカスタムヘッダー
        var isJMeterRequest = context.Request.Headers["X-Skip-Logging"] == "true";

        if (!isJMeterRequest)
        {
            // 通常のログ処理
            var sessionId = context.Request.Headers["SessionId"].ToString();
            var requestUrl = context.Request.Path;
            var httpMethod = context.Request.Method;
            var requestHeaders = context.Request.Headers.ToString();
            var requestBody = await ReadRequestBodyAsync(context.Request);

            var stopwatch = Stopwatch.StartNew();
            await _next(context);
            stopwatch.Stop();

            var responseTime = stopwatch.ElapsedMilliseconds;
            var responseCode = context.Response.StatusCode;
            var errorDetails = responseCode != 200 ? "Error details" : null;

            // 一意のタグを付与
            var logTag = "MiddlewareLog";

            if (responseCode != 200)
            {
                Log.ForContext("LogTag", logTag)
                   .ForContext("SessionId", sessionId)
                   .ForContext("URL", requestUrl)
                   .ForContext("HTTPMethod", httpMethod)
                   .ForContext("RequestHeaders", requestHeaders)
                   .ForContext("RequestBody", requestBody)
                   .ForContext("ResponseTime", responseTime)
                   .ForContext("ResponseCode", responseCode)
                   .ForContext("ErrorDetails", errorDetails)
                   .Error("API error with session ID {SessionId}");
            }
            else
            {
                Log.ForContext("LogTag", logTag)
                   .ForContext("SessionId", sessionId)
                   .ForContext("URL", requestUrl)
                   .ForContext("HTTPMethod", httpMethod)
                   .ForContext("RequestHeaders", requestHeaders)
                   .ForContext("RequestBody", requestBody)
                   .ForContext("ResponseTime", responseTime)
                   .ForContext("ResponseCode", responseCode)
                   .Information("API request processed successfully with session ID {SessionId}");
            }
        }
        else
        {
            // JMeterからのリクエストの場合、次のミドルウェアへ処理を渡すのみ
            await _next(context);
        }
    }

    private async Task<string> ReadRequestBodyAsync(HttpRequest request)
    {
        request.EnableBuffering();
        using (var reader = new StreamReader(request.Body, leaveOpen: true))
        {
            var body = await reader.ReadToEndAsync();
            request.Body.Position = 0;
            return body;
        }
    }
}
```

ミドルウェアの登録
Startup.csのConfigureメソッドにて、ミドルウェアをASP.NET Coreパイプラインに登録します。

```
public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
{
    app.UseMiddleware<RequestResponseLoggingMiddleware>();

    // 他のミドルウェア
    app.UseRouting();
    app.UseAuthentication();
    app.UseAuthorization();
    app.UseEndpoints(endpoints =>
    {
        endpoints.MapControllers();
    });
}

```
## ログを定期的に収集する方法

Datadogから定期的にログを収集し、k6などの負荷試験ツールで利用するためのインプットデータとして保存するプロセスを自動化できます。

2.1 PowerShellスクリプトによるログ収集
以下のPowerShellスクリプトは、Datadogから特定のタグ（LogTag:MiddlewareLog）に基づいたログを定期的に収集し、CSV形式で保存します。

```
$APIKey = "YOUR_DATADOG_API_KEY"
$AppKey = "YOUR_DATADOG_APP_KEY"
$DatadogApiUrl = "https://api.datadoghq.com/api/v2/logs/events/search"
$Query = 'LogTag:MiddlewareLog'  # 特定のタグに基づくクエリ

function Get-TimeRange {
    $EndTime = (Get-Date).ToUniversalTime()
    $StartTime = $EndTime.AddMinutes(-10)
    return @{StartTime = $StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ"); EndTime = $EndTime.ToString("yyyy-MM-ddTHH:mm:ssZ")}
}

function Fetch-Logs {
    $TimeRange = Get-TimeRange

    $Headers = @{
        "DD-API-KEY" = $APIKey
        "DD-APPLICATION-KEY" = $AppKey
        "Content-Type" = "application/json"
    }

    $Params = @{
        "filter[query]" = $Query
        "filter[from]" = $TimeRange.StartTime
        "filter[to]" = $TimeRange.EndTime
        "page[limit]" = "1000"
    }

    $Uri = $DatadogApiUrl + "?" + ($Params.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } -join "&")

    $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get

    if ($Response.data) {
        return $Response.data
    } else {
        Write-Host "Failed to fetch logs: $($Response.message)"
        return $null
    }
}

function Save-Logs {
    param (
        [Parameter(Mandatory=$true)]
        [array]$Logs,
        [string]$OutputFile = "k6_input_data.csv"
    )

    $csvContent = @()
    foreach ($log in $Logs) {
        $endpoint = $log.attributes.http.url
        $method = $log.attributes.http.method
        $headers = "Authorization: Bearer $($log.attributes.headers['Authorization'])"
        $body = $log.attributes.http.body

        $csvContent += "$endpoint,$method,$headers,$body"
    }

    $csvContent | Out-File -FilePath $OutputFile
    Write-Host "Input data saved to $OutputFile"
}

function Run-Batch {
    while ($true) {
        $Logs = Fetch-Logs
        if ($Logs) {
            Save-Logs -Logs $Logs
        }

        Start-Sleep -Seconds 600
    }
}

Run-Batch

```

## k6でのログ利用

2.1 k6での利用準備
ログデータの整形: 収集したログデータをk6で使用可能な形式に整形。具体的には、CSV形式に変換し、APIエンドポイント、HTTPメソッド、リクエストヘッダー、リクエストボディなどのデータを含める。
PowerShellスクリプトを使用して、Datadogから取得したログデータをCSV形式で保存し、k6で利用できるように準備。
2.2 k6スクリプトでのデータ利用
CSVデータのインポート: k6スクリプトで、SharedArrayやopen関数を利用して、CSVファイルからAPIリクエストデータを読み込み、テストシナリオで使用。
例: k6スクリプトでは、CSVファイルから読み込んだデータをもとに、各APIエンドポイントへのリクエストを動的に生成し、負荷試験を実行。

```
import http from 'k6/http';
import { SharedArray } from 'k6/data';

const inputData = new SharedArray('input data', function() {
    return open('./k6_input_data.csv').split('\n').slice(1).map(row => {
        const [endpoint, method, headers, body] = row.split(',');
        return {
            endpoint: endpoint.trim(),
            method: method.trim(),
            headers: JSON.parse(headers.trim()),
            body: body ? JSON.parse(body.trim()) : ''
        };
    });
});

export let options = {
    vus: 10,
    duration: '1m',
};

export default function () {
    inputData.forEach(data => {
        http.request(data.method, data.endpoint, data.body, {
            headers: data.headers
        });
    });
}


```