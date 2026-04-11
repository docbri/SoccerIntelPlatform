using System.Text.Json;
using Confluent.Kafka;
using Microsoft.Extensions.Logging;

namespace Platform.BronzeConsumer;

public sealed class FileQuarantineWriter(
    string outputPath,
    RetryOptions retryOptions,
    ILogger<FileQuarantineWriter> logger) : IQuarantineWriter
{
    public async Task WriteAsync(
        ConsumeResult<Ignore, string> result,
        string reason,
        CancellationToken cancellationToken,
        List<string>? validationErrors = null)
    {
        await RetryHelper.ExecuteAsync(
            async () =>
            {
                Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);

                var record = new QuarantineRecord
                {
                    Reason = reason,
                    ValidationErrors = validationErrors ?? [],
                    KafkaTopic = result.Topic,
                    KafkaPartition = result.Partition.Value,
                    KafkaOffset = result.Offset.Value,
                    KafkaTimestampUtc = result.Message.Timestamp.UtcDateTime,
                    QuarantinedAtUtc = DateTime.UtcNow,
                    RawMessageJson = result.Message.Value
                };

                var line = JsonSerializer.Serialize(record);
                await File.AppendAllTextAsync(outputPath, line + Environment.NewLine, cancellationToken);
            },
            retryOptions,
            logger,
            "Write quarantine record",
            cancellationToken);
    }
}
