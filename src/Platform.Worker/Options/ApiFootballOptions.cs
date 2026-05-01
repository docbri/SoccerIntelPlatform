namespace Platform.Worker.Options;

public sealed class ApiFootballOptions
{
    public const string SectionName = "ApiFootball";

    public string BaseUrl { get; set; } = string.Empty;
    public string ApiKey { get; set; } = string.Empty;
    public List<int> LeagueIds { get; set; } = [];
    public int Season { get; set; }
    public int PollIntervalSeconds { get; set; } = 60;
    public int MaxCallsPerDay { get; set; } = 100;
    public bool Enabled { get; set; } = false;
}
