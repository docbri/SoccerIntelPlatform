using Confluent.Kafka;
using Platform.BronzeConsumer;
using Microsoft.Extensions.Logging.Abstractions;

namespace Platform.BronzeConsumer.UnitTests;

public sealed class BronzeMessageProcessorTests
{
    [Fact]
    public async Task ProcessAsync_Quarantines_Invalid_Json()
    {
        var idempotencyStore = new InMemoryIdempotencyStore();
        var bronzeWriter = new FakeBronzeWriter();
        var quarantineWriter = new FakeQuarantineWriter();
        var processor = new BronzeMessageProcessor(
            bronzeWriter,
            quarantineWriter,
            idempotencyStore,
            NullLogger<BronzeMessageProcessor>.Instance);

        var result = BuildConsumeResult("not valid json");

        var processingResult = await processor.ProcessAsync(result, CancellationToken.None);

        Assert.False(processingResult.WrittenToBronze);
        Assert.True(processingResult.WrittenToQuarantine);
        Assert.Contains("JSON deserialization failure", processingResult.Outcome);
        Assert.Empty(bronzeWriter.Rows);
        Assert.Single(quarantineWriter.Records);
    }

    [Fact]
    public async Task ProcessAsync_Writes_Valid_Message_To_Bronze()
    {
        var idempotencyStore = new InMemoryIdempotencyStore();
        var bronzeWriter = new FakeBronzeWriter();
        var quarantineWriter = new FakeQuarantineWriter();
        var processor = new BronzeMessageProcessor(
            bronzeWriter,
            quarantineWriter,
            idempotencyStore,
            NullLogger<BronzeMessageProcessor>.Instance);
        
        var validJson =
            "{\"SchemaVersion\":\"1.0\",\"Source\":\"api-football\",\"EntityType\":\"league-status\",\"LeagueId\":135,\"LeagueName\":\"Serie A\",\"Season\":2025,\"CorrelationId\":\"corr-123\",\"FetchedAtUtc\":\"2026-04-10T12:00:00Z\",\"Endpoint\":\"/status\",\"RequestKey\":\"status-135-2025\",\"SourceEntityId\":\"135\",\"PayloadJson\":\"{\\\"ok\\\":true}\"}";

        var result = BuildConsumeResult(validJson);

        var processingResult = await processor.ProcessAsync(result, CancellationToken.None);

        Assert.True(processingResult.WrittenToBronze);
        Assert.False(processingResult.WrittenToQuarantine);
        Assert.Single(bronzeWriter.Rows);
        Assert.Empty(quarantineWriter.Records);
    }
    
    [Fact]
    public async Task ProcessAsync_Skips_Duplicate_Message()
    {
        var bronzeWriter = new FakeBronzeWriter();
        var quarantineWriter = new FakeQuarantineWriter();
        var idempotencyStore = new InMemoryIdempotencyStore();

        var processor = new BronzeMessageProcessor(
            bronzeWriter,
            quarantineWriter,
            idempotencyStore,
            NullLogger<BronzeMessageProcessor>.Instance);

        var validJson =
            "{\"SchemaVersion\":\"1.0\",\"Source\":\"api-football\",\"EntityType\":\"league-status\",\"LeagueId\":135,\"LeagueName\":\"Serie A\",\"Season\":2025,\"CorrelationId\":\"corr-123\",\"FetchedAtUtc\":\"2026-04-10T12:00:00Z\",\"Endpoint\":\"/status\",\"RequestKey\":\"status-135-2025\",\"SourceEntityId\":\"135\",\"PayloadJson\":\"{\\\"ok\\\":true}\"}";

        var result = BuildConsumeResult(validJson);

        await processor.ProcessAsync(result, CancellationToken.None);
        await processor.ProcessAsync(result, CancellationToken.None);

        Assert.Single(bronzeWriter.Rows);
    }

    private static ConsumeResult<Ignore, string> BuildConsumeResult(string value)
    {
        return new ConsumeResult<Ignore, string>
        {
            Topic = "soccer.raw.ingestion.dev",
            Partition = new Partition(0),
            Offset = new Offset(1),
            Message = new Message<Ignore, string>
            {
                Value = value,
                Timestamp = new Timestamp(DateTime.UtcNow)
            }
        };
    }

    private sealed class FakeBronzeWriter : IBronzeWriter
    {
        public List<BronzeRow> Rows { get; } = [];

        public Task WriteAsync(BronzeRow bronzeRow, CancellationToken cancellationToken)
        {
            Rows.Add(bronzeRow);
            return Task.CompletedTask;
        }
    }

    private sealed class FakeQuarantineWriter : IQuarantineWriter
    {
        public List<(string Reason, List<string>? ValidationErrors, string RawMessageJson)> Records { get; } = [];

        public Task WriteAsync(
            ConsumeResult<Ignore, string> result,
            string reason,
            CancellationToken cancellationToken,
            List<string>? validationErrors = null)
        {
            Records.Add((reason, validationErrors, result.Message.Value));
            return Task.CompletedTask;
        }
    }
}

