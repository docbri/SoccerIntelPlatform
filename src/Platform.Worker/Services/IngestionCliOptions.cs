namespace Platform.Worker.Services;

public sealed class IngestionCliOptions
{
    public string? Mode { get; private init; }
    public int? PollIntervalSeconds { get; private init; }
    public int? MaxCallsPerDay { get; private init; }

    public bool IsOnceMode =>
        string.Equals(Mode, "once", StringComparison.OrdinalIgnoreCase);

    public bool IsPollMode =>
        string.Equals(Mode, "poll", StringComparison.OrdinalIgnoreCase);

    public bool HasExplicitMode =>
        !string.IsNullOrWhiteSpace(Mode);

    public static IngestionCliOptions Parse(string[] args)
    {
        string? mode = null;
        int? pollIntervalSeconds = null;
        int? maxCallsPerDay = null;

        for (var i = 0; i < args.Length; i++)
        {
            var current = args[i];

            switch (current)
            {
                case "--mode":
                    mode = ReadRequiredValue(args, ref i, "--mode");
                    break;

                case "--poll-interval-seconds":
                    pollIntervalSeconds = ReadRequiredPositiveInteger(args, ref i, "--poll-interval-seconds");
                    break;

                case "--max-calls-per-day":
                    maxCallsPerDay = ReadRequiredPositiveInteger(args, ref i, "--max-calls-per-day");
                    break;
            }
        }

        if (!string.IsNullOrWhiteSpace(mode) &&
            !string.Equals(mode, "once", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(mode, "poll", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                $"Unsupported ingestion mode '{mode}'. Supported modes are 'once' and 'poll'.");
        }

        return new IngestionCliOptions
        {
            Mode = mode,
            PollIntervalSeconds = pollIntervalSeconds,
            MaxCallsPerDay = maxCallsPerDay
        };
    }

    private static string ReadRequiredValue(string[] args, ref int index, string optionName)
    {
        if (index + 1 >= args.Length)
        {
            throw new InvalidOperationException($"{optionName} requires a value.");
        }

        index++;
        return args[index];
    }

    private static int ReadRequiredPositiveInteger(string[] args, ref int index, string optionName)
    {
        var rawValue = ReadRequiredValue(args, ref index, optionName);

        if (!int.TryParse(rawValue, out var value) || value <= 0)
        {
            throw new InvalidOperationException($"{optionName} must be a positive integer. Received: {rawValue}");
        }

        return value;
    }
}
