namespace Platform.Api.Infrastructure.Databricks;

public sealed class DatabricksSqlRow
{
    public Dictionary<string, object?> Values { get; set; } = new();
}

