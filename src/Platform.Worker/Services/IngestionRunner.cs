using Microsoft.Extensions.Options;
using Platform.Shared.Contracts;
using Platform.Worker.Infrastructure.ApiFootball;
using Platform.Worker.Infrastructure.Kafka;
using Platform.Worker.Options;

namespace Platform.Worker.Services;

public sealed class IngestionRunner(
    ILogger<IngestionRunner> logger,
    IOptions<ApiFootballOptions> apiFootballOptions,
    IApiFootballClient apiFootballClient,
    IKafkaPublisher kafkaPublisher,
    ApiFootballCallLedger apiFootballCallLedger)
{
    private readonly ILogger<IngestionRunner> _logger = logger;
    private readonly ApiFootballOptions _apiFootballOptions = apiFootballOptions.Value;
    private readonly IApiFootballClient _apiFootballClient = apiFootballClient;
    private readonly IKafkaPublisher _kafkaPublisher = kafkaPublisher;
    private readonly ApiFootballCallLedger _apiFootballCallLedger = apiFootballCallLedger;

    public async Task RunOnceAsync(CancellationToken cancellationToken)
    {
        ValidateOptions();

        var hasRealApiKey = HasRealApiKey();

        _logger.LogInformation("Starting one controlled ingestion pass.");
        _logger.LogInformation("API-Football BaseUrl: {BaseUrl}", _apiFootballOptions.BaseUrl);
        _logger.LogInformation("Configured Season: {Season}", _apiFootballOptions.Season);
        _logger.LogInformation("Configured LeagueIds: {LeagueIds}", string.Join(", ", _apiFootballOptions.LeagueIds));
        _logger.LogInformation("Max Calls Per Day: {MaxCallsPerDay}", _apiFootballOptions.MaxCallsPerDay);

        if (!hasRealApiKey)
        {
            _logger.LogWarning(
                "API-Football API key is not configured with a real value. The worker will publish synthetic warning envelopes and will not reserve daily API quota.");
        }

        foreach (var leagueId in _apiFootballOptions.LeagueIds)
        {
            if (hasRealApiKey)
            {
                var reserved = await _apiFootballCallLedger.TryReserveCallAsync(
                    _apiFootballOptions.MaxCallsPerDay,
                    cancellationToken);

                if (!reserved)
                {
                    _logger.LogWarning(
                        "Skipping API-Football call for LeagueId={LeagueId} because the daily call limit has been reached.",
                        leagueId);

                    continue;
                }
            }

            IngestionEnvelope envelope;

            try
            {
                envelope = await _apiFootballClient.GetLeagueStatusAsync(
                    leagueId,
                    _apiFootballOptions.Season,
                    cancellationToken);
            }
            finally
            {
                if (hasRealApiKey)
                {
                    await _apiFootballCallLedger.MarkCallCompletedAsync(cancellationToken);
                }
            }

            await _kafkaPublisher.PublishAsync(envelope, cancellationToken);

            _logger.LogInformation(
                "Envelope processed: Source={Source}, EntityType={EntityType}, LeagueId={LeagueId}, PayloadLength={PayloadLength}",
                envelope.Source,
                envelope.EntityType,
                envelope.LeagueId,
                envelope.PayloadJson.Length);
        }

        _logger.LogInformation("Controlled ingestion pass completed.");
    }

    public async Task RunPollingAsync(CancellationToken cancellationToken)
    {
        ValidateOptions();

        _logger.LogInformation("Polling ingestion started at {UtcNow}", DateTime.UtcNow);
        _logger.LogInformation("Poll Interval Seconds: {PollIntervalSeconds}", _apiFootballOptions.PollIntervalSeconds);
        _logger.LogInformation("Max Calls Per Day: {MaxCallsPerDay}", _apiFootballOptions.MaxCallsPerDay);

        while (!cancellationToken.IsCancellationRequested)
        {
            await RunOnceAsync(cancellationToken);

            _logger.LogInformation("=== INGESTION HEARTBEAT === {UtcNow}", DateTime.UtcNow);

            await Task.Delay(
                TimeSpan.FromSeconds(_apiFootballOptions.PollIntervalSeconds),
                cancellationToken);
        }
    }

    private bool HasRealApiKey()
    {
        return !string.IsNullOrWhiteSpace(_apiFootballOptions.ApiKey) &&
               !string.Equals(_apiFootballOptions.ApiKey, "replace-me-later", StringComparison.OrdinalIgnoreCase) &&
               !string.Equals(_apiFootballOptions.ApiKey, "development-key-placeholder", StringComparison.OrdinalIgnoreCase);
    }

    private void ValidateOptions()
    {
        if (string.IsNullOrWhiteSpace(_apiFootballOptions.BaseUrl))
        {
            throw new InvalidOperationException("ApiFootball:BaseUrl is required.");
        }

        if (_apiFootballOptions.LeagueIds.Count == 0)
        {
            throw new InvalidOperationException("ApiFootball:LeagueIds must contain at least one league id.");
        }

        if (_apiFootballOptions.Season <= 0)
        {
            throw new InvalidOperationException("ApiFootball:Season must be configured.");
        }

        if (_apiFootballOptions.PollIntervalSeconds <= 0)
        {
            throw new InvalidOperationException("ApiFootball:PollIntervalSeconds must be positive.");
        }

        if (_apiFootballOptions.MaxCallsPerDay <= 0)
        {
            throw new InvalidOperationException("ApiFootball:MaxCallsPerDay must be positive.");
        }
    }
}
