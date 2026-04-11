namespace Platform.Api.Infrastructure.Databricks;

public interface IDatabricksSqlClient
{
    Task<IReadOnlyList<DatabricksSqlRow>> QueryAsync(
        string sql,
        CancellationToken cancellationToken);
}

