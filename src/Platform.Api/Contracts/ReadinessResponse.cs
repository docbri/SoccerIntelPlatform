namespace Platform.Api.Contracts;

public sealed class ReadinessResponse
{
    public string Status { get; set; } = string.Empty;
    public DateTime Utc { get; set; }
    public IReadOnlyList<ReadinessCheck> Checks { get; set; } = [];
}

public sealed class ReadinessCheck
{
    public string Name { get; set; } = string.Empty;
    public bool Ok { get; set; }
    public string? Error { get; set; }
}
