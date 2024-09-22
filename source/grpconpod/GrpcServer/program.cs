using Microsoft.Extensions.Hosting;
using System.Threading.Tasks;

public class Program
{
    public static async Task Main(string[] args)
    {
        var host = Host.CreateDefaultBuilder(args)
            .ConfigureGrpcServerWithHttp3(5001)  // HTTP/3対応のgRPCサーバーを設定
            .Build();

        await host.RunAsync();
    }
}
