namespace Platform.BronzeConsumer;

public sealed class EnvelopeValidationResult
{
    public bool IsValid { get; init; }
    public List<string> Errors { get; init; } = [];

    public static EnvelopeValidationResult Valid() =>
        new() { IsValid = true };

    public static EnvelopeValidationResult Invalid(params string[] errors) =>
        new() { IsValid = false, Errors = errors.ToList() };
}

