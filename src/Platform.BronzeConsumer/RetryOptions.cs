namespace Platform.BronzeConsumer;

public sealed class RetryOptions
{
    public int MaxAttempts { get; set; } = 3;
    public int DelayMilliseconds { get; set; } = 200;
}

