using Confluent.Kafka;
using Microsoft.Extensions.Logging;

namespace Platform.BronzeConsumer;

public sealed class BronzeConsumerService(
    BronzeConsumerOptions options,
    IBronzeMessageProcessor messageProcessor,
    ILogger<BronzeConsumerService> logger)
{
    public async Task RunAsync(CancellationToken cancellationToken)
    {
        var config = new ConsumerConfig
        {
            BootstrapServers = options.BootstrapServers,
            GroupId = options.ConsumerGroupId,
            AutoOffsetReset = AutoOffsetReset.Earliest
        };

        using var consumer = new ConsumerBuilder<Ignore, string>(config).Build();
        consumer.Subscribe(options.TopicName);

        logger.LogInformation("Subscribed to topic: {TopicName}", options.TopicName);
        logger.LogInformation("Consumer group: {ConsumerGroupId}", options.ConsumerGroupId);
        logger.LogInformation("Writing Bronze rows to: {BronzeOutputPath}", options.BronzeOutputPath);
        logger.LogInformation("Writing quarantined rows to: {QuarantineOutputPath}", options.QuarantineOutputPath);
        logger.LogInformation("Press Ctrl-C to stop.");

        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var result = consumer.Consume(cancellationToken);

                var processingResult = await messageProcessor.ProcessAsync(result, cancellationToken);

                logger.LogInformation("{Outcome}", processingResult.Outcome);
            }
        }
        catch (OperationCanceledException)
        {
            logger.LogInformation("Stopping consumer...");
        }
        finally
        {
            consumer.Close();
        }
    }
}
