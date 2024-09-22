# .NET 8を使用したgRPC通信でHTTP/3を利用し、Kubernetes内でローカルホスト優先のリトライ処理を実装する方法
gRPCは、軽量で高速なリモートプロシージャコール（RPC）プロトコルで、特にマイクロサービス間の通信に最適化されています。また、.NET 8ではgRPC通信にHTTP/3がサポートされ、より高速で効率的な通信が可能です。本記事では、Kubernetes環境下でローカルホスト上のPodに優先的に接続し、通信に失敗した場合には他のホスト上のPodにリトライするgRPC通信ライブラリを構築する手順を解説します。

## 目次
- HTTP/3とgRPCの概要
- Kubernetes環境でのPod間通信の課題
- .NET 8でのHTTP/3サポート
- gRPC通信ライブラリの構築
- ローカルホスト優先のPod間リトライ処理

## 1. HTTP/3とgRPCの概要
gRPCはGoogleが開発したRPC（リモートプロシージャコール）フレームワークで、特にマイクロサービスの通信やクライアント・サーバー間の効率的なデータ送受信に適しています。従来のHTTP/2をベースにしていましたが、HTTP/3のサポートによりさらに低遅延での通信が可能となりました。

HTTP/3は、UDPベースのQUICプロトコルを使用しており、パフォーマンスが大幅に改善され、再接続やセッション管理がスムーズです。これにより、gRPC通信も一層最適化されます。

## 2. Kubernetes環境でのPod間通信の課題
Kubernetesでは、複数のPodがサービスとして稼働しますが、ネットワークの再構築や障害発生時に通信相手のPodが再起動・移動することが一般的です。そのため、Pod間通信の際には、通信先のPodが存在しない、もしくは停止している可能性を考慮する必要があります。

特に、複数のホスト間で負荷分散されたPod間通信において、同じホストにあるPodに優先的に接続することで、ネットワーク遅延を低減することが可能です。しかし、同じホストにあるPodに接続できない場合には、他のホスト上にあるPodにリトライする処理が必要です。

## 3. .NET 8でのHTTP/3サポート
.NET 8では、HttpClientとGrpc.Net.ClientがHTTP/3に対応しています。gRPC通信でHTTP/3を有効にするには、SocketsHttpHandlerの設定でHTTP/3を指定します。

```csharpコードをコピーする
var handler = new SocketsHttpHandler
{
    EnableMultipleHttp2Connections = true,  // HTTP/2も有効化
    AllowAutoRedirect = false,
    RequestVersion = new Version(3, 0),  // HTTP/3を指定
    RequestVersionPolicy = HttpVersionPolicy.RequestVersionOrHigher
};
```
HTTP/3を利用したgRPCチャンネルを作成することで、.NET 8上で最適化された通信が可能です。

## 4. gRPC通信ライブラリの構築
まず、gRPCクライアントを用いて、KubernetesのPod間通信を行うライブラリを構築します。このライブラリでは、最初に同じホスト上のPodに接続し、失敗した場合は他のホスト上のPodにリトライするロジックを追加します。

KubernetesPodLocatorクラス
このクラスは、Kubernetes APIを使用して同じホストに配置されたPodのIPアドレスを優先的に取得し、その他のホストのPodをリストに追加します。

```csharpコードをコピーする
using System.Collections.Generic;
using System.Threading.Tasks;
using k8s;

public class KubernetesPodLocator
{
    private readonly IKubernetes _kubernetesClient;

    public KubernetesPodLocator()
    {
        var config = KubernetesClientConfiguration.InClusterConfig();
        _kubernetesClient = new Kubernetes(config);
    }

    public async Task<(List<string> sameHostPodIps, List<string> otherHostPodIps)> GetPodIpsAsync(string currentPodName)
    {
        var sameHostPodIps = new List<string>();
        var otherHostPodIps = new List<string>();
        var pods = await _kubernetesClient.ListNamespacedPodAsync("default");
        var currentHostIp = GetCurrentHostIp();

        foreach (var pod in pods.Items)
        {
            if (pod.Metadata.Name != currentPodName)
            {
                if (pod.Status.HostIP == currentHostIp)
                {
                    sameHostPodIps.Add(pod.Status.PodIP);  // 同じホスト上のPodを優先
                }
                else
                {
                    otherHostPodIps.Add(pod.Status.PodIP);  // 他のホスト上のPod
                }
            }
        }

        return (sameHostPodIps, otherHostPodIps);
    }

    private string GetCurrentHostIp()
    {
        // 環境に応じたホストIP取得処理
        return "127.0.0.1";  // ダウンワードAPI等を利用可能
    }
}
```
GrpcServiceCommunicatorクラス
このクラスは、まずローカルホストのPodに接続し、失敗した場合に他のホストのPodにリトライする処理を実装しています。また、HTTP/3でのgRPC通信を行います。

```csharpコードをコピーする
using Grpc.Net.Client;
using Polly;
using Polly.Retry;
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Threading.Tasks;

public class GrpcServiceCommunicator
{
    private readonly string _serviceName;
    private readonly int _port;
    private readonly List<string> _sameHostPodIps;
    private readonly List<string> _otherHostPodIps;
    private int _currentPodIndex = 0;
    private readonly AsyncRetryPolicy _retryPolicy;

    public GrpcServiceCommunicator(string serviceName, int port, List<string> sameHostPodIps, List<string> otherHostPodIps)
    {
        _serviceName = serviceName;
        _port = port;
        _sameHostPodIps = sameHostPodIps;
        _otherHostPodIps = otherHostPodIps;

        // リトライポリシーの定義
        _retryPolicy = Policy
            .Handle<HttpRequestException>()
            .Or<Grpc.Core.RpcException>()
            .WaitAndRetryAsync(3, retryAttempt => TimeSpan.FromSeconds(2), (exception, timeSpan, retryCount, context) =>
            {
                Console.WriteLine($"リトライ {retryCount}/{3} - エラー: {exception.Message}");
            });
    }

    public async Task<TResponse> SendRequestAsync<TRequest, TResponse>(TRequest request, Func<Greeter.GreeterClient, TRequest, Task<TResponse>> grpcMethod)
    {
        return await _retryPolicy.ExecuteAsync(async () =>
        {
            // 最初に同じホストのPodに接続
            var podIps = _sameHostPodIps.Count > 0 ? _sameHostPodIps : _otherHostPodIps;

            try
            {
                var currentPodIp = podIps[_currentPodIndex];
                return await SendRequestToPodAsync(currentPodIp, request, grpcMethod);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ローカルホストのPodに接続できませんでした。エラー: {ex.Message}");

                // 他のホストのPodにリトライ
                if (_otherHostPodIps.Count > 0)
                {
                    return await SendRequestToOtherPodsAsync(request, grpcMethod);
                }
                throw;
            }
        });
    }

    private async Task<TResponse> SendRequestToPodAsync<TRequest, TResponse>(string podIp, TRequest request, Func<Greeter.GreeterClient, TRequest, Task<TResponse>> grpcMethod)
    {
        var handler = new SocketsHttpHandler
        {
            EnableMultipleHttp2Connections = true,
            AllowAutoRedirect = false,
            RequestVersion = new Version(3, 0),
            RequestVersionPolicy = HttpVersionPolicy.RequestVersionOrHigher
        };

        var httpClient = new HttpClient(handler);
        var grpcChannel = GrpcChannel.ForAddress($"https://{podIp}:{_port}", new GrpcChannelOptions
        {
            HttpClient = httpClient
        });

        var client = new Greeter.GreeterClient(grpcChannel);
        return await grpcMethod(client, request);
    }

    private async Task<TResponse> SendRequestToOtherPodsAsync<TRequest, TResponse>(TRequest request, Func<Greeter.GreeterClient, TRequest, Task<TResponse>> grpcMethod)
    {
        for (int i = 0; i < _otherHostPodIps.Count; i++)
        {
            try
            {
                var currentPodIp = _otherHostPodIps[i];
                return await SendRequestToPodAsync(currentPodIp, request, grpcMethod);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"他のPod {i + 1}/{_otherHostPodIps.Count} に失敗しました: {ex.Message}");
            }
        }

        throw new Exception("全てのPodへの接続が失敗しました。");
    }
}
```
## 5. ローカルホスト優先のPod間リトライ処理
上記のGrpcServiceCommunicatorでは、最初に同じホストにあるPodに接続を試み、失敗した場合は他のホストのPodにリトライします。Pollyライブラリを利用したリトライポリシーも設定されており、ネットワークの一時的な障害にも対応可能です。