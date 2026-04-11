namespace Platform.BronzeConsumer;

public sealed class MessageProcessingResult
{
    public bool WrittenToBronze { get; init; }
    public bool WrittenToQuarantine { get; init; }
    public string Outcome { get; init; } = string.Empty;

    public static MessageProcessingResult Bronze(string outcome = "Written to Bronze") =>
        new()
        {
            WrittenToBronze = true,
            WrittenToQuarantine = false,
            Outcome = outcome
        };

    public static MessageProcessingResult Quarantine(string outcome) =>
        new()
        {
            WrittenToBronze = false,
            WrittenToQuarantine = true,
            Outcome = outcome
        };
}

