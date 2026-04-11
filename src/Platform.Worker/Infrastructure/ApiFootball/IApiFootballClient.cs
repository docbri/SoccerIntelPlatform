using Platform.Shared.Contracts;

namespace Platform.Worker.Infrastructure.ApiFootball;

public interface IApiFootballClient
{
    Task<IngestionEnvelope> GetLeagueStatusAsync(
        int leagueId,
        int season,
        CancellationToken cancellationToken);
}
