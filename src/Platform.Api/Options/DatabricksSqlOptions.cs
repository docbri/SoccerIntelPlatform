namespace Platform.Api.Options;

public sealed class DatabricksSqlOptions
{
    public const string SectionName = "DatabricksSql";

    public string WorkspaceUrl { get; set; } = string.Empty;
    public string WarehouseId { get; set; } = string.Empty;

    // Unity Catalog namespace (Section A contract)
    public string Catalog { get; set; } = string.Empty;
    public string Schema { get; set; } = "gold";
    public string CurrentLeagueStatusObjectName { get; set; } = "current_league_status";

    public string AuthenticationType { get; set; } = "Stub";
    public string AccessToken { get; set; } = string.Empty;
}
