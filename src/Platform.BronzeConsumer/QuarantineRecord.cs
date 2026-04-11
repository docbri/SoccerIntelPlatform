namespace Platform.BronzeConsumer;

public sealed class QuarantineRecord
{
    public string Reason { get; set; } = string.Empty;
    public List<string> ValidationErrors { get; set; } = [];
    public string KafkaTopic { get; set; } = string.Empty;
    public int KafkaPartition { get; set; }
    public long KafkaOffset { get; set; }
    public DateTime KafkaTimestampUtc { get; set; }
    public DateTime QuarantinedAtUtc { get; set; }
    public string RawMessageJson { get; set; } = string.Empty;
}
