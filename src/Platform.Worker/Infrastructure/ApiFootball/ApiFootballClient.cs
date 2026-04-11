using System.Net.Http.Headers;
using Platform.Shared.Contracts;
using Platform.Worker.Options;

namespace Platform.Worker.Infrastructure.ApiFootball;

public sealed class ApiFootballClient(
    HttpClient httpClient,
    ILogger<ApiFootballClient> logger,
    IConfiguration configuration) : IApiFootballClient
{
    private readonly HttpClient _httpClient = httpClient;
    private readonly ILogger<ApiFootballClient> _logger = logger;
    private readonly IConfiguration _configuration = configuration;

    public async Task<IngestionEnvelope> GetLeagueStatusAsync(
        int leagueId,
        int season,
        CancellationToken cancellationToken)
    {
        var apiKey = _configuration[$"{ApiFootballOptions.SectionName}:ApiKey"];

        if (string.IsNullOrWhiteSpace(apiKey) || apiKey == "replace-me-later" || apiKey == "development-key-placeholder")
        {
            _logger.LogWarning("API-Football API key is not configured with a real value.");

            return new IngestionEnvelope
            {
                Source = "api-football",
                EntityType = "league-status",
                LeagueId = leagueId,
                LeagueName = $"League-{leagueId}",
                Season = season,
                Endpoint = "/status",
                RequestKey = $"status-{leagueId}-{season}",
                SourceEntityId = leagueId.ToString(),
                PayloadJson = """{"warning":"API key not configured"}"""
            };
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, "status");
        request.Headers.Add("x-apisports-key", apiKey);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        _logger.LogInformation("API-Football status call returned HTTP {StatusCode}", (int)response.StatusCode);

        response.EnsureSuccessStatusCode();

        return new IngestionEnvelope
        {
            Source = "api-football",
            EntityType = "league-status",
            LeagueId = leagueId,
            LeagueName = $"League-{leagueId}",
            Season = season,
            Endpoint = "/status",
            RequestKey = $"status-{leagueId}-{season}",
            SourceEntityId = leagueId.ToString(),
            PayloadJson = payload
        };
    }
}
