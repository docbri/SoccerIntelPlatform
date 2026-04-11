using Microsoft.Extensions.Options;
using Platform.Shared.Contracts;
using Platform.Worker.Infrastructure.ApiFootball;
using Platform.Worker.Infrastructure.Kafka;
using Platform.Worker.Options;

namespace Platform.Worker.Services;

public sealed class PollingWorker(
    ILogger<PollingWorker> logger,
    IOptions<ApiFootballOptions> apiFootballOptions,
    IApiFootballClient apiFootballClient,
    IKafkaPublisher kafkaPublisher) : BackgroundService
{
    private readonly ILogger<PollingWorker> _logger = logger;
    private readonly ApiFootballOptions _apiFootballOptions = apiFootballOptions.Value;
    private readonly IApiFootballClient _apiFootballClient = apiFootballClient;
    private readonly IKafkaPublisher _kafkaPublisher = kafkaPublisher;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("PollingWorker started at {UtcNow}", DateTime.UtcNow);
        _logger.LogInformation("API-Football BaseUrl: {BaseUrl}", _apiFootballOptions.BaseUrl);
        _logger.LogInformation("Configured Season: {Season}", _apiFootballOptions.Season);
        _logger.LogInformation("Configured LeagueIds: {LeagueIds}", string.Join(", ", _apiFootballOptions.LeagueIds));
        _logger.LogInformation("Poll Interval Seconds: {PollIntervalSeconds}", _apiFootballOptions.PollIntervalSeconds);

        while (!stoppingToken.IsCancellationRequested)
        {
            foreach (var leagueId in _apiFootballOptions.LeagueIds)
            {
                IngestionEnvelope envelope = await _apiFootballClient.GetLeagueStatusAsync(
                    leagueId,
                    _apiFootballOptions.Season,
                    stoppingToken);

                await _kafkaPublisher.PublishAsync(envelope, stoppingToken);

                _logger.LogInformation(
                    "Envelope processed: Source={Source}, EntityType={EntityType}, LeagueId={LeagueId}, PayloadLength={PayloadLength}",
                    envelope.Source,
                    envelope.EntityType,
                    envelope.LeagueId,
                    envelope.PayloadJson.Length);
            }

            _logger.LogInformation("=== HEARTBEAT === {UtcNow}", DateTime.UtcNow);

            await Task.Delay(
                TimeSpan.FromSeconds(_apiFootballOptions.PollIntervalSeconds),
                stoppingToken);
        }
    }
}
