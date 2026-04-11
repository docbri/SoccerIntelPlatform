using Platform.Api.Contracts;
using Platform.Api.Infrastructure.Databricks;

namespace Platform.Api.Services;

public sealed class LeagueStatusReadService(
    IDatabricksSqlClient databricksSqlClient) : ILeagueStatusReadService
{
    public async Task<IReadOnlyList<CurrentLeagueStatusResponse>> GetCurrentStatusesAsync(
        int? leagueId,
        int? season,
        CancellationToken cancellationToken)
    {
        var sql = BuildSql(leagueId, season);

        var rows = await databricksSqlClient.QueryAsync(sql, cancellationToken);

        return rows.Select(MapRow).ToList();
    }

    private static string BuildSql(int? leagueId, int? season)
    {
        var conditions = new List<string>();

        if (leagueId.HasValue)
        {
            conditions.Add($"league_id = {leagueId.Value}");
        }

        if (season.HasValue)
        {
            conditions.Add($"season = {season.Value}");
        }

        var whereClause = conditions.Count > 0
            ? $" WHERE {string.Join(" AND ", conditions)}"
            : string.Empty;

        return
            "SELECT league_id, league_name, season, status_category, api_status, api_warning, latest_fetched_at_utc, latest_ingested_at_utc " +
            "FROM gold.current_league_status" +
            whereClause;
    }

    private static CurrentLeagueStatusResponse MapRow(DatabricksSqlRow row)
    {
        return new CurrentLeagueStatusResponse
        {
            LeagueId = Convert.ToInt32(row.Values["league_id"]),
            LeagueName = Convert.ToString(row.Values["league_name"]) ?? string.Empty,
            Season = Convert.ToInt32(row.Values["season"]),
            StatusCategory = Convert.ToString(row.Values["status_category"]) ?? string.Empty,
            ApiStatus = row.Values["api_status"] as string,
            ApiWarning = row.Values["api_warning"] as string,
            LatestFetchedAtUtc = Convert.ToDateTime(row.Values["latest_fetched_at_utc"]),
            LatestIngestedAtUtc = Convert.ToDateTime(row.Values["latest_ingested_at_utc"])
        };
    }
}

