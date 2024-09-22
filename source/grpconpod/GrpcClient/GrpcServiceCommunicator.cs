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

        // リトライポリシーの定義（3回リトライ、2秒間隔）
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
