using Platform.BronzeConsumer;
using Platform.Shared.Contracts;

namespace Platform.BronzeConsumer.UnitTests;

public sealed class BronzeRowMapperTests
{
    [Fact]
    public void Map_Maps_All_Envelope_Fields_And_Kafka_Metadata()
    {
        var envelope = new IngestionEnvelope
        {
            SchemaVersion = "1.0",
            Source = "api-football",
            EntityType = "league-status",
            LeagueId = 135,
            LeagueName = "Serie A",
            Season = 2025,
            CorrelationId = "corr-123",
            FetchedAtUtc = new DateTime(2026, 4, 10, 12, 0, 0, DateTimeKind.Utc),
            Endpoint = "/status",
            RequestKey = "status-135-2025",
            SourceEntityId = "135",
            PayloadJson = "{\"ok\":true}"
        };

        var kafkaTimestampUtc = new DateTime(2026, 4, 10, 12, 1, 0, DateTimeKind.Utc);
        var ingestedAtUtc = new DateTime(2026, 4, 10, 12, 2, 0, DateTimeKind.Utc);
        var rawMessageJson = "{\"raw\":\"message\"}";

        var result = BronzeRowMapper.Map(
            envelope,
            kafkaTopic: "soccer.raw.ingestion.dev",
            kafkaPartition: 0,
            kafkaOffset: 42,
            kafkaTimestampUtc: kafkaTimestampUtc,
            ingestedAtUtc: ingestedAtUtc,
            rawMessageJson: rawMessageJson);

        Assert.Equal(envelope.SchemaVersion, result.SchemaVersion);
        Assert.Equal(envelope.Source, result.Source);
        Assert.Equal(envelope.EntityType, result.EntityType);
        Assert.Equal(envelope.LeagueId, result.LeagueId);
        Assert.Equal(envelope.LeagueName, result.LeagueName);
        Assert.Equal(envelope.Season, result.Season);
        Assert.Equal(envelope.CorrelationId, result.CorrelationId);
        Assert.Equal(envelope.FetchedAtUtc, result.FetchedAtUtc);
        Assert.Equal(envelope.Endpoint, result.Endpoint);
        Assert.Equal(envelope.RequestKey, result.RequestKey);
        Assert.Equal(envelope.SourceEntityId, result.SourceEntityId);
        Assert.Equal(envelope.PayloadJson, result.PayloadJson);

        Assert.Equal("soccer.raw.ingestion.dev", result.KafkaTopic);
        Assert.Equal(0, result.KafkaPartition);
        Assert.Equal(42, result.KafkaOffset);
        Assert.Equal(kafkaTimestampUtc, result.KafkaTimestampUtc);
        Assert.Equal(ingestedAtUtc, result.IngestedAtUtc);
        Assert.Equal(rawMessageJson, result.RawMessageJson);
    }
}
