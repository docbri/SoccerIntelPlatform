using Platform.Worker.Infrastructure.ApiFootball;
using Platform.Worker.Infrastructure.Kafka;
using Platform.Worker.Options;
using Platform.Worker.Services;

var builder = Host.CreateApplicationBuilder(args);

builder.Services
    .AddOptions<ApiFootballOptions>()
    .Bind(builder.Configuration.GetSection(ApiFootballOptions.SectionName));

builder.Services
    .AddOptions<KafkaOptions>()
    .Bind(builder.Configuration.GetSection(KafkaOptions.SectionName));

builder.Services.AddHttpClient<IApiFootballClient, ApiFootballClient>((serviceProvider, client) =>
{
    var config = serviceProvider.GetRequiredService<IConfiguration>();
    var baseUrl = config[$"{ApiFootballOptions.SectionName}:BaseUrl"];

    client.BaseAddress = new Uri(baseUrl!);
});

builder.Services.AddSingleton<IKafkaPublisher, KafkaPublisher>();

var apiFootballSection = builder.Configuration.GetSection(ApiFootballOptions.SectionName);
var apiFootballOptions = apiFootballSection.Get<ApiFootballOptions>();

if (apiFootballOptions?.Enabled == true)
{
    builder.Services.AddHostedService<PollingWorker>();
}
else
{
    Console.WriteLine("PollingWorker is disabled by configuration.");
}

var host = builder.Build();
host.Run();
