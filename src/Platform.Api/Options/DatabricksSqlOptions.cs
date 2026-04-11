namespace Platform.Api.Options;

public sealed class DatabricksSqlOptions
{
    public const string SectionName = "DatabricksSql";

    public string WorkspaceUrl { get; set; } = string.Empty;
    public string WarehouseId { get; set; } = string.Empty;
    public string Catalog { get; set; } = "gold";
    public string Schema { get; set; } = "default";
    public string AuthenticationType { get; set; } = "Stub";
    public string AccessToken { get; set; } = string.Empty;
}

