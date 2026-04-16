using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Platform.Api.Infrastructure.Databricks;
using Xunit;

public class ReadinessEndpointTests
{
    [Fact]
    public async Task Ready_WhenDownstreamOk_Returns200AndReadyStatus()
    {
        using var factory = new WebApplicationFactory<Program>();
        var client = factory.CreateClient();

        var response = await client.GetAsync("/ready");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);

        Assert.Equal("Ready", doc.RootElement.GetProperty("status").GetString());
        Assert.True(doc.RootElement.TryGetProperty("checks", out var checks));
        Assert.True(checks.GetArrayLength() >= 1);

        var databricks = checks.EnumerateArray()
            .First(c => c.GetProperty("name").GetString() == "databricks");
        Assert.True(databricks.GetProperty("ok").GetBoolean());
    }

    [Fact]
    public async Task Ready_WhenDownstreamThrows_Returns503AndNotReadyStatus()
    {
        using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureTestServices(services =>
                {
                    services.RemoveAll<IDatabricksSqlClient>();
                    services.AddSingleton<IDatabricksSqlClient, ThrowingDatabricksSqlClient>();
                });
            });

        var client = factory.CreateClient();

        var response = await client.GetAsync("/ready");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);

        Assert.Equal("NotReady", doc.RootElement.GetProperty("status").GetString());

        var databricks = doc.RootElement.GetProperty("checks").EnumerateArray()
            .First(c => c.GetProperty("name").GetString() == "databricks");
        Assert.False(databricks.GetProperty("ok").GetBoolean());
        Assert.False(string.IsNullOrWhiteSpace(databricks.GetProperty("error").GetString()));
    }

    private sealed class ThrowingDatabricksSqlClient : IDatabricksSqlClient
    {
        public Task<IReadOnlyList<DatabricksSqlRow>> QueryAsync(
            string sql,
            CancellationToken cancellationToken)
        {
            throw new InvalidOperationException("Simulated downstream failure for readiness test.");
        }
    }
}
