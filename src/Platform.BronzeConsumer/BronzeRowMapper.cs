using Platform.Shared.Contracts;

namespace Platform.BronzeConsumer;

public static class BronzeRowMapper
{
    public static BronzeRow Map(
        IngestionEnvelope envelope,
        string kafkaTopic,
        int kafkaPartition,
        long kafkaOffset,
        DateTime kafkaTimestampUtc,
        DateTime ingestedAtUtc,
        string rawMessageJson)
    {
        return new BronzeRow
        {
            SchemaVersion = envelope.SchemaVersion,
            Source = envelope.Source,
            EntityType = envelope.EntityType,
            LeagueId = envelope.LeagueId,
            LeagueName = envelope.LeagueName,
            Season = envelope.Season,
            CorrelationId = envelope.CorrelationId,
            FetchedAtUtc = envelope.FetchedAtUtc,
            Endpoint = envelope.Endpoint,
            RequestKey = envelope.RequestKey,
            SourceEntityId = envelope.SourceEntityId,
            PayloadJson = envelope.PayloadJson,
            KafkaTopic = kafkaTopic,
            KafkaPartition = kafkaPartition,
            KafkaOffset = kafkaOffset,
            KafkaTimestampUtc = kafkaTimestampUtc,
            IngestedAtUtc = ingestedAtUtc,
            RawMessageJson = rawMessageJson
        };
    }
}
