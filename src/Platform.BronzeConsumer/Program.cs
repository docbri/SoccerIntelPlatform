using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Platform.BronzeConsumer;

var environmentName = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production";

var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: false)
    .AddJsonFile($"appsettings.{environmentName}.json", optional: true, reloadOnChange: false)
    .AddEnvironmentVariables()
    .Build();

var options = configuration
    .GetSection(BronzeConsumerOptions.SectionName)
    .Get<BronzeConsumerOptions>()
    ?? throw new InvalidOperationException("BronzeConsumer configuration section is missing.");

using var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddSimpleConsole(options =>
    {
        options.SingleLine = true;
        options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
    });

    builder.SetMinimumLevel(LogLevel.Information);
});

var startupLogger = loggerFactory.CreateLogger("Startup");
startupLogger.LogInformation("Environment: {EnvironmentName}", environmentName);

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    cts.Cancel();
};

var bronzeWriterLogger = loggerFactory.CreateLogger<FileBronzeWriter>();
IBronzeWriter bronzeWriter =
    new FileBronzeWriter(options.BronzeOutputPath, options.Retry, bronzeWriterLogger);

var quarantineWriterLogger = loggerFactory.CreateLogger<FileQuarantineWriter>();
IQuarantineWriter quarantineWriter =
    new FileQuarantineWriter(options.QuarantineOutputPath, options.Retry, quarantineWriterLogger);

IIdempotencyStore idempotencyStore = new InMemoryIdempotencyStore();
var processorLogger = loggerFactory.CreateLogger<BronzeMessageProcessor>();
IBronzeMessageProcessor messageProcessor =
    new BronzeMessageProcessor(
        bronzeWriter,
        quarantineWriter,
        idempotencyStore,
        processorLogger);

var serviceLogger = loggerFactory.CreateLogger<BronzeConsumerService>();
var service = new BronzeConsumerService(options, messageProcessor, serviceLogger);

await service.RunAsync(cts.Token);
