using Platform.Shared.Contracts;

namespace Platform.BronzeConsumer;

public static class IdempotencyKeyBuilder
{
    public static string Build(IngestionEnvelope envelope)
    {
        return $"{envelope.Source}|{envelope.EntityType}|{envelope.RequestKey}";
    }
}

