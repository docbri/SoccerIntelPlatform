using Platform.BronzeConsumer;
using Platform.Shared.Contracts;

namespace Platform.BronzeConsumer.UnitTests;

public sealed class IngestionEnvelopeValidatorTests
{
    [Fact]
    public void Validate_Returns_Valid_For_Acceptable_Envelope()
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

        var result = IngestionEnvelopeValidator.Validate(envelope);

        Assert.True(result.IsValid);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public void Validate_Returns_Invalid_For_Missing_Required_Fields()
    {
        var envelope = new IngestionEnvelope
        {
            SchemaVersion = "1.0",
            Source = "",
            EntityType = "league-status",
            LeagueId = 0,
            LeagueName = "Bad League",
            Season = 2025,
            CorrelationId = "corr-bad-1",
            FetchedAtUtc = new DateTime(2026, 4, 10, 12, 0, 0, DateTimeKind.Utc),
            Endpoint = "/status",
            RequestKey = "",
            SourceEntityId = "",
            PayloadJson = ""
        };

        var result = IngestionEnvelopeValidator.Validate(envelope);

        Assert.False(result.IsValid);
        Assert.Contains("Source is required.", result.Errors);
        Assert.Contains("LeagueId must be greater than zero.", result.Errors);
        Assert.Contains("RequestKey is required.", result.Errors);
        Assert.Contains("SourceEntityId is required.", result.Errors);
        Assert.Contains("PayloadJson is required.", result.Errors);
    }
}

