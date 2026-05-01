namespace Platform.Worker.Services;

public sealed class PollingWorker(
    ILogger<PollingWorker> logger,
    IngestionRunner ingestionRunner) : BackgroundService
{
    private readonly ILogger<PollingWorker> _logger = logger;
    private readonly IngestionRunner _ingestionRunner = ingestionRunner;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("PollingWorker started at {UtcNow}", DateTime.UtcNow);

        await _ingestionRunner.RunPollingAsync(stoppingToken);
    }
}
