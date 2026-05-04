using System.Text.Json;
using Confluent.Kafka;
using Microsoft.Extensions.Logging;
using Platform.Shared.Contracts;

namespace Platform.BronzeConsumer;

public sealed class BronzeMessageProcessor(
    IBronzeWriter bronzeWriter,
    IQuarantineWriter quarantineWriter,
    IIdempotencyStore idempotencyStore,
    ILogger<BronzeMessageProcessor> logger) : IBronzeMessageProcessor
{
    public async Task<MessageProcessingResult> ProcessAsync(
        ConsumeResult<Ignore, string> result,
        CancellationToken cancellationToken)
    {
        IngestionEnvelope? envelope;

        try
        {
            envelope = JsonSerializer.Deserialize<IngestionEnvelope>(result.Message.Value);
        }
        catch (JsonException ex)
        {
            logger.LogWarning(
                ex,
                "Quarantining offset {Offset} due to JSON deserialization failure.",
                result.Offset.Value);

            await quarantineWriter.WriteAsync(
                result,
                "JSON deserialization failure",
                cancellationToken);

            return MessageProcessingResult.Quarantine("JSON deserialization failure");
        }

        if (envelope is null)
        {
            logger.LogWarning(
                "Quarantining offset {Offset} because envelope deserialized to null.",
                result.Offset.Value);

            await quarantineWriter.WriteAsync(
                result,
                "Envelope deserialized to null",
                cancellationToken);

            return MessageProcessingResult.Quarantine("Envelope deserialized to null");
        }

        var validationResult = IngestionEnvelopeValidator.Validate(envelope);

        if (!validationResult.IsValid)
        {
            logger.LogWarning(
                "Quarantining offset {Offset} because envelope failed validation: {ValidationErrors}",
                result.Offset.Value,
                string.Join("; ", validationResult.Errors));

            await quarantineWriter.WriteAsync(
                result,
                "Envelope validation failure",
                cancellationToken,
                validationResult.Errors);

            return MessageProcessingResult.Quarantine(
                $"Envelope validation failure: {string.Join("; ", validationResult.Errors)}");
        }

        var idempotencyKey = IdempotencyKeyBuilder.Build(envelope, result);

        if (idempotencyStore.HasSeen(idempotencyKey))
        {
            logger.LogInformation(
                "Skipping duplicate message with key {IdempotencyKey}.",
                idempotencyKey);

            return MessageProcessingResult.Bronze("Duplicate skipped");
        }

        var bronzeRow = BronzeRowMapper.Map(
            envelope,
            result.Topic,
            result.Partition.Value,
            result.Offset.Value,
            result.Message.Timestamp.UtcDateTime,
            DateTime.UtcNow,
            result.Message.Value);

        await bronzeWriter.WriteAsync(bronzeRow, cancellationToken);

        idempotencyStore.MarkSeen(idempotencyKey);

        logger.LogInformation(
            "Wrote Bronze row for topic {Topic} partition {Partition} offset {Offset}.",
            bronzeRow.KafkaTopic,
            bronzeRow.KafkaPartition,
            bronzeRow.KafkaOffset);

        return MessageProcessingResult.Bronze(
            $"Consumed offset {bronzeRow.KafkaOffset} from {bronzeRow.KafkaTopic} and wrote Bronze row.");
    }
}
