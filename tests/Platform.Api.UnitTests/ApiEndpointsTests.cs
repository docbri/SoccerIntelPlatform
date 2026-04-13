using Microsoft.AspNetCore.Mvc.Testing;
using System.Net;
using System.Text.Json;
using Xunit;

public class ApiEndpointsTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ApiEndpointsTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task ConfigSources_Returns200_AndExpectedShape()
    {
        var response = await _client.GetAsync("/config/sources");

        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();

        using var doc = JsonDocument.Parse(json);

        Assert.True(doc.RootElement.TryGetProperty("primary", out _));
        Assert.True(doc.RootElement.TryGetProperty("supportedLeagues", out _));
        Assert.True(doc.RootElement.TryGetProperty("activeLeagueIds", out _));
        Assert.True(doc.RootElement.TryGetProperty("season", out _));
    }

    [Fact]
    public async Task LeagueStatusCurrent_Returns200()
    {
        var response = await _client.GetAsync("/league-status/current");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task LeagueStatusCurrent_WithQueryParams_Returns200()
    {
        var response = await _client.GetAsync("/league-status/current?leagueId=135&season=2025");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}

