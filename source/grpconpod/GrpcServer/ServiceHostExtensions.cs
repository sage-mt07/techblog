using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Net;

public static class ServiceHostExtensions
{
    public static IHostBuilder ConfigureGrpcServerWithHttp3(this IHostBuilder hostBuilder, int port, bool useHttp2 = true)
    {
        return hostBuilder.ConfigureWebHostDefaults(webBuilder =>
        {
            webBuilder.ConfigureKestrel(serverOptions =>
            {
                // KestrelでHTTP/3対応を有効化
                serverOptions.Listen(IPAddress.Any, port, listenOptions =>
                {
                    listenOptions.Protocols = HttpProtocols.Http1AndHttp2AndHttp3;  // HTTP/1, HTTP/2, HTTP/3全てをサポート
                    listenOptions.UseHttps();  // HTTP/3は通常HTTPSを使用
                });

                if (useHttp2)
                {
                    serverOptions.Listen(IPAddress.Any, port + 1, listenOptions =>
                    {
                        listenOptions.Protocols = HttpProtocols.Http2;
                        listenOptions.UseHttps();
                    });
                }
            });

            webBuilder.UseStartup<Startup>();
        });
    }

    public static void AddGrpcServices(this IServiceCollection services)
    {
        services.AddGrpc();
    }
}
