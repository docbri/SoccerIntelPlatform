namespace Platform.Worker.Options;

public sealed class KafkaOptions
{
    public const string SectionName = "Kafka";

    public string BootstrapServers { get; set; } = "localhost:9092";
    public string TopicName { get; set; } = "soccer.raw.ingestion";
}
