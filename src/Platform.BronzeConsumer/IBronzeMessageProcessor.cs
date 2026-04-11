using Confluent.Kafka;

namespace Platform.BronzeConsumer;

public interface IBronzeMessageProcessor
{
    Task<MessageProcessingResult> ProcessAsync(
        ConsumeResult<Ignore, string> result,
        CancellationToken cancellationToken);
}

