namespace Platform.BronzeConsumer;

public sealed class BronzeRow
{
    public string SchemaVersion { get; set; } = string.Empty;
    public string Source { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public int LeagueId { get; set; }
    public string LeagueName { get; set; } = string.Empty;
    public int Season { get; set; }
    public string CorrelationId { get; set; } = string.Empty;
    public DateTime FetchedAtUtc { get; set; }
    public string Endpoint { get; set; } = string.Empty;
    public string RequestKey { get; set; } = string.Empty;
    public string SourceEntityId { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = string.Empty;

    public string KafkaTopic { get; set; } = string.Empty;
    public int KafkaPartition { get; set; }
    public long KafkaOffset { get; set; }
    public DateTime KafkaTimestampUtc { get; set; }
    public DateTime IngestedAtUtc { get; set; }
    public string RawMessageJson { get; set; } = string.Empty;
}

