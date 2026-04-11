namespace Platform.BronzeConsumer;

public interface IBronzeWriter
{
    Task WriteAsync(BronzeRow bronzeRow, CancellationToken cancellationToken);
}

