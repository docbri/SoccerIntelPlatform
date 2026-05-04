using Confluent.Kafka;
using Platform.Shared.Contracts;

namespace Platform.BronzeConsumer;

public static class IdempotencyKeyBuilder
{
    public static string Build(
        IngestionEnvelope envelope,
        ConsumeResult<Ignore, string> result)
    {
        return $"{result.Topic}|{result.Partition.Value}|{result.Offset.Value}";
    }
}
