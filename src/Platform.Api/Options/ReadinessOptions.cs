namespace Platform.Api.Options;

public sealed class ReadinessOptions
{
    public const string SectionName = "Readiness";

    public int DatabricksTimeoutSeconds { get; set; } = 60;
}

