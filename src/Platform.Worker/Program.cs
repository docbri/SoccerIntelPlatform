using Microsoft.Extensions.Options;
using Platform.Worker.Infrastructure.ApiFootball;
using Platform.Worker.Infrastructure.Kafka;
using Platform.Worker.Options;
using Platform.Worker.Services;

var ingestionCliOptions = IngestionCliOptions.Parse(args);

var builder = Host.CreateApplicationBuilder(args);

builder.Services
    .AddOptions<ApiFootballOptions>()
    .Bind(builder.Configuration.GetSection(ApiFootballOptions.SectionName));

builder.Services.PostConfigure<ApiFootballOptions>(options =>
{
    if (ingestionCliOptions.PollIntervalSeconds.HasValue)
    {
        options.PollIntervalSeconds = ingestionCliOptions.PollIntervalSeconds.Value;
    }

    if (ingestionCliOptions.MaxCallsPerDay.HasValue)
    {
        options.MaxCallsPerDay = ingestionCliOptions.MaxCallsPerDay.Value;
    }

    if (ingestionCliOptions.IsPollMode)
    {
        options.Enabled = true;
    }
});

builder.Services
    .AddOptions<KafkaOptions>()
    .Bind(builder.Configuration.GetSection(KafkaOptions.SectionName));

builder.Services.AddHttpClient<IApiFootballClient, ApiFootballClient>((serviceProvider, client) =>
{
    var config = serviceProvider.GetRequiredService<IConfiguration>();
    var baseUrl = config[$"{ApiFootballOptions.SectionName}:BaseUrl"];

    if (string.IsNullOrWhiteSpace(baseUrl))
    {
        throw new InvalidOperationException("ApiFootball:BaseUrl is required.");
    }

    client.BaseAddress = new Uri(baseUrl);
});

builder.Services.AddSingleton<IKafkaPublisher, KafkaPublisher>();
builder.Services.AddSingleton<ApiFootballCallLedger>();
builder.Services.AddSingleton<IngestionRunner>();

var apiFootballSection = builder.Configuration.GetSection(ApiFootballOptions.SectionName);
var apiFootballOptions = apiFootballSection.Get<ApiFootballOptions>() ?? new ApiFootballOptions();

if (ingestionCliOptions.PollIntervalSeconds.HasValue)
{
    apiFootballOptions.PollIntervalSeconds = ingestionCliOptions.PollIntervalSeconds.Value;
}

if (ingestionCliOptions.MaxCallsPerDay.HasValue)
{
    apiFootballOptions.MaxCallsPerDay = ingestionCliOptions.MaxCallsPerDay.Value;
}

if (ingestionCliOptions.IsOnceMode)
{
    using var host = builder.Build();

    var runner = host.Services.GetRequiredService<IngestionRunner>();

    await runner.RunOnceAsync(CancellationToken.None);

    return;
}

if (ingestionCliOptions.IsPollMode || apiFootballOptions.Enabled)
{
    builder.Services.AddHostedService<PollingWorker>();
}
else
{
    Console.WriteLine("PollingWorker is disabled by configuration.");
    Console.WriteLine("Run with --mode once for one controlled ingestion pass.");
    Console.WriteLine("Run with --mode poll for continuous polling.");
}

var runningHost = builder.Build();
await runningHost.RunAsync();
