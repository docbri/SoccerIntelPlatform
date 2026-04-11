namespace Platform.BronzeConsumer;

public sealed class BronzeConsumerOptions
{
    public const string SectionName = "BronzeConsumer";

    public string BootstrapServers { get; set; } = "localhost:9092";
    public string TopicName { get; set; } = "soccer.raw.ingestion.dev";
    public string ConsumerGroupId { get; set; } = "platform-bronze-consumer-dev";
    public string BronzeOutputPath { get; set; } = "localdata/bronze/raw_ingestion_events.jsonl";
    public string QuarantineOutputPath { get; set; } = "localdata/quarantine/raw_ingestion_quarantine.jsonl";
    public RetryOptions Retry { get; set; } = new();
}
