using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        // gRPCサービスを登録
        services.AddGrpc();
    }

    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        if (env.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
        }

        app.UseRouting();

        app.UseEndpoints(endpoints =>
        {
            // gRPCサービスのエンドポイントを設定
            endpoints.MapGrpcService<MyGrpcService>();

            // 簡易的なヘルスチェックエンドポイント
            endpoints.MapGet("/", async context =>
            {
                await context.Response.WriteAsync("gRPC service is running.");
            });
        });
    }
}
