namespace Platform.Api.Options;

public sealed class SourceOptions
{
    public const string SectionName = "Sources";

    public string Primary { get; set; } = string.Empty;
    public List<string> SupportedLeagues { get; set; } = [];
    public List<int> ActiveLeagueIds { get; set; } = [];
    public int Season { get; set; }
}
