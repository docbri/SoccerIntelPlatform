using Microsoft.Extensions.Options;
using MicrosoftOptions = Microsoft.Extensions.Options.Options;
using Platform.Api.Infrastructure.Databricks;
using Platform.Api.Options;
using Platform.Api.Services;

namespace Platform.Api.UnitTests;

public class LeagueStatusReadServiceTests
{
    [Fact]
    public async Task BuildsSql_WithNoFilters_ReturnsAll()
    {
        var fakeClient = new FakeDatabricksSqlClient();
        var service = new LeagueStatusReadService(fakeClient, TestDatabricksOptions());

        await service.GetCurrentStatusesAsync(null, null, CancellationToken.None);

        Assert.Contains("FROM soccerintel_staging.gold.current_league_status", fakeClient.LastSql);
        Assert.DoesNotContain("WHERE", fakeClient.LastSql);
    }

    [Fact]
    public async Task BuildsSql_WithLeagueId_AddsFilter()
    {
        var fakeClient = new FakeDatabricksSqlClient();
        var service = new LeagueStatusReadService(fakeClient, TestDatabricksOptions());

        await service.GetCurrentStatusesAsync(135, null, CancellationToken.None);

        Assert.Contains("league_id = 135", fakeClient.LastSql);
    }

    [Fact]
    public async Task BuildsSql_WithSeason_AddsFilter()
    {
        var fakeClient = new FakeDatabricksSqlClient();
        var service = new LeagueStatusReadService(fakeClient, TestDatabricksOptions());

        await service.GetCurrentStatusesAsync(null, 2025, CancellationToken.None);

        Assert.Contains("season = 2025", fakeClient.LastSql);
    }

    [Fact]
    public async Task MapsRow_Correctly()
    {
        var now = DateTime.UtcNow;

        var fakeClient = new FakeDatabricksSqlClient
        {
            Rows =
            [
                new DatabricksSqlRow
                {
                    Values = new Dictionary<string, object?>
                    {
                        ["league_id"] = 135,
                        ["league_name"] = "Serie A",
                        ["season"] = 2025,
                        ["status_category"] = "ok",
                        ["api_status"] = "green",
                        ["api_warning"] = (string?)null,
                        ["latest_fetched_at_utc"] = now,
                        ["latest_ingested_at_utc"] = now
                    }
                }
            ]
        };

        var service = new LeagueStatusReadService(fakeClient, TestDatabricksOptions());

        var result = await service.GetCurrentStatusesAsync(null, null, CancellationToken.None);

        Assert.Single(result);
        Assert.Equal(135, result[0].LeagueId);
        Assert.Equal("Serie A", result[0].LeagueName);
        Assert.Equal(2025, result[0].Season);
        Assert.Equal("ok", result[0].StatusCategory);
        Assert.Equal("green", result[0].ApiStatus);
        Assert.Null(result[0].ApiWarning);
        Assert.Equal(now, result[0].LatestFetchedAtUtc);
        Assert.Equal(now, result[0].LatestIngestedAtUtc);
    }

    private static IOptions<DatabricksSqlOptions> TestDatabricksOptions()
    {
        return MicrosoftOptions.Create(new DatabricksSqlOptions
        {
            Catalog = "soccerintel_staging",
            Schema = "gold",
            CurrentLeagueStatusObjectName = "current_league_status"
        });
    }

    private sealed class FakeDatabricksSqlClient : IDatabricksSqlClient
    {
        public string LastSql { get; private set; } = string.Empty;

        public IReadOnlyList<DatabricksSqlRow> Rows { get; set; } = [];

        public Task<IReadOnlyList<DatabricksSqlRow>> QueryAsync(string sql, CancellationToken cancellationToken)
        {
            LastSql = sql;
            return Task.FromResult(Rows);
        }
    }
}
