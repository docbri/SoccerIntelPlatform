namespace Platform.Api.Contracts;

public sealed class CurrentLeagueStatusResponse
{
    public int LeagueId { get; set; }
    public string LeagueName { get; set; } = string.Empty;
    public int Season { get; set; }
    public string StatusCategory { get; set; } = string.Empty;
    public string? ApiStatus { get; set; }
    public string? ApiWarning { get; set; }
    public DateTime LatestFetchedAtUtc { get; set; }
    public DateTime LatestIngestedAtUtc { get; set; }
}

