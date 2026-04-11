using Platform.Api.Contracts;

namespace Platform.Api.Services;

public interface ILeagueStatusReadService
{
    Task<IReadOnlyList<CurrentLeagueStatusResponse>> GetCurrentStatusesAsync(
        int? leagueId,
        int? season,
        CancellationToken cancellationToken);
}

