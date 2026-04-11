using System.Text.Json;
using Confluent.Kafka;
using Microsoft.Extensions.Options;
using Platform.Shared.Contracts;
using Platform.Worker.Options;

namespace Platform.Worker.Infrastructure.Kafka;

public sealed class KafkaPublisher(
    IOptions<KafkaOptions> kafkaOptions,
    ILogger<KafkaPublisher> logger) : IKafkaPublisher, IDisposable
{
    private readonly KafkaOptions _kafkaOptions = kafkaOptions.Value;
    private readonly ILogger<KafkaPublisher> _logger = logger;

    private readonly IProducer<Null, string> _producer =
        new ProducerBuilder<Null, string>(
            new ProducerConfig
            {
                BootstrapServers = kafkaOptions.Value.BootstrapServers
            }).Build();

    public async Task PublishAsync(IngestionEnvelope envelope, CancellationToken cancellationToken)
    {
        var payload = JsonSerializer.Serialize(envelope);

        var result = await _producer.ProduceAsync(
            _kafkaOptions.TopicName,
            new Message<Null, string>
            {
                Value = payload
            },
            cancellationToken);

        _logger.LogInformation(
            "Published envelope to Kafka topic {TopicName} at offset {Offset}",
            result.Topic,
            result.Offset.Value);
    }

    public void Dispose()
    {
        _producer.Flush(TimeSpan.FromSeconds(5));
        _producer.Dispose();
    }
}
