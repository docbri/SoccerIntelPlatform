namespace Platform.Shared.Contracts;

public sealed class IngestionEnvelope
{
    public string SchemaVersion { get; set; } = "1.0";
    public string Source { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;

    public int LeagueId { get; set; }
    public string LeagueName { get; set; } = string.Empty;
    public int Season { get; set; }

    public string CorrelationId { get; set; } = Guid.NewGuid().ToString();
    public DateTime FetchedAtUtc { get; set; } = DateTime.UtcNow;

    public string Endpoint { get; set; } = string.Empty;
    public string RequestKey { get; set; } = string.Empty;
    public string SourceEntityId { get; set; } = string.Empty;

    public string PayloadJson { get; set; } = string.Empty;
}
