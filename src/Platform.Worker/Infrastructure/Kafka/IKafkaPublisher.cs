using Platform.Shared.Contracts;

namespace Platform.Worker.Infrastructure.Kafka;

public interface IKafkaPublisher
{
    Task PublishAsync(IngestionEnvelope envelope, CancellationToken cancellationToken);
}
