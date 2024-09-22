using System;
using System.Threading.Tasks;

public class Program
{
    public static async Task Main(string[] args)
    {
        var podLocator = new KubernetesPodLocator();
        var currentPodName = Environment.GetEnvironmentVariable("POD_NAME");
        var (sameHostPodIps, otherHostPodIps) = await podLocator.GetPodIpsAsync(currentPodName);

        var grpcCommunicator = new GrpcServiceCommunicator("my-grpc-service", 5000, sameHostPodIps, otherHostPodIps);

        // gRPCリクエストの送信
        var response = await grpcCommunicator.SendRequestAsync<HelloRequest, HelloReply>(
            new HelloRequest { Name = "World" },
            (client, request) => client.SayHelloAsync(request)
        );

        Console.WriteLine($"Response from gRPC service: {response.Message}");
    }
}
