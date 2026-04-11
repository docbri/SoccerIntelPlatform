namespace Platform.Api.Infrastructure.Databricks;

public sealed class StubDatabricksSqlClient : IDatabricksSqlClient
{
    public Task<IReadOnlyList<DatabricksSqlRow>> QueryAsync(
        string sql,
        CancellationToken cancellationToken)
    {
        IReadOnlyList<DatabricksSqlRow> rows =
        [
            new DatabricksSqlRow
            {
                Values = new Dictionary<string, object?>
                {
                    ["league_id"] = 135,
                    ["league_name"] = "Serie A",
                    ["season"] = 2025,
                    ["status_category"] = "warning",
                    ["api_status"] = null,
                    ["api_warning"] = "API key not configured",
                    ["latest_fetched_at_utc"] = DateTime.UtcNow.AddMinutes(-5),
                    ["latest_ingested_at_utc"] = DateTime.UtcNow.AddMinutes(-4)
                }
            }
        ];

        return Task.FromResult(rows);
    }
}

