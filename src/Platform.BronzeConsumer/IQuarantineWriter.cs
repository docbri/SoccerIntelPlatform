using Confluent.Kafka;

namespace Platform.BronzeConsumer;

public interface IQuarantineWriter
{
    Task WriteAsync(
        ConsumeResult<Ignore, string> result,
        string reason,
        CancellationToken cancellationToken,
        List<string>? validationErrors = null);
}

