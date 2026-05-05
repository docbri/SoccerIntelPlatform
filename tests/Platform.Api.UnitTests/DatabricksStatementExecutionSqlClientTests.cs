using System.Net;
using System.Text;
using System.Text.Json;
using MicrosoftOptions = Microsoft.Extensions.Options.Options;
using Platform.Api.Infrastructure.Databricks;
using Platform.Api.Options;

namespace Platform.Api.UnitTests;

public sealed class DatabricksStatementExecutionSqlClientTests
{
    [Fact]
    public async Task QueryAsync_ParsesSucceededInlineJsonArrayResponse()
    {
        var responseJson = """
        {
          "statement_id": "stmt-123",
          "status": {
            "state": "SUCCEEDED"
          },
          "manifest": {
            "schema": {
              "columns": [
                { "name": "league_id" },
                { "name": "league_name" },
                { "name": "season" },
                { "name": "status_category" },
                { "name": "api_status" },
                { "name": "api_warning" },
                { "name": "latest_fetched_at_utc" },
                { "name": "latest_ingested_at_utc" }
              ]
            },
            "total_row_count": 1
          },
          "result": {
            "data_array": [
              [
                "135",
                "Serie A",
                "2025",
                "warning",
                null,
                "API key not configured",
                "2026-05-04T20:00:00Z",
                "2026-05-04T20:01:00Z"
              ]
            ]
          }
        }
        """;

        var handler = new StubHttpMessageHandler(responseJson);
        var client = CreateClient(handler);

        var rows = await client.QueryAsync("SELECT * FROM table", CancellationToken.None);

        Assert.Single(rows);

        var row = rows[0];

        Assert.Equal("135", row.Values["league_id"]);
        Assert.Equal("Serie A", row.Values["league_name"]);
        Assert.Equal("2025", row.Values["season"]);
        Assert.Equal("warning", row.Values["status_category"]);
        Assert.Null(row.Values["api_status"]);
        Assert.Equal("API key not configured", row.Values["api_warning"]);
        Assert.Equal("2026-05-04T20:00:00Z", row.Values["latest_fetched_at_utc"]);
        Assert.Equal("2026-05-04T20:01:00Z", row.Values["latest_ingested_at_utc"]);

        Assert.Equal(HttpMethod.Post, handler.LastRequest?.Method);
        Assert.Equal("https://example.cloud.databricks.com/api/2.0/sql/statements/", handler.LastRequest?.RequestUri?.ToString());
        Assert.Equal("Bearer test-token", handler.LastRequest?.Headers.Authorization?.ToString());

        Assert.NotNull(handler.LastRequestBody);

        using var requestDoc = JsonDocument.Parse(handler.LastRequestBody!);
        Assert.Equal("SELECT * FROM table", requestDoc.RootElement.GetProperty("statement").GetString());
        Assert.Equal("warehouse-123", requestDoc.RootElement.GetProperty("warehouse_id").GetString());
        Assert.Equal("INLINE", requestDoc.RootElement.GetProperty("disposition").GetString());
        Assert.Equal("JSON_ARRAY", requestDoc.RootElement.GetProperty("format").GetString());
    }

    [Fact]
    public async Task QueryAsync_ReturnsEmptyList_WhenSucceededResponseHasNoRows()
    {
        var responseJson = """
        {
          "statement_id": "stmt-123",
          "status": {
            "state": "SUCCEEDED"
          },
          "manifest": {
            "schema": {
              "columns": [
                { "name": "league_id" }
              ]
            },
            "total_row_count": 0
          },
          "result": {
            "data_array": []
          }
        }
        """;

        var client = CreateClient(new StubHttpMessageHandler(responseJson));

        var rows = await client.QueryAsync("SELECT * FROM table", CancellationToken.None);

        Assert.Empty(rows);
    }

    [Fact]
    public async Task QueryAsync_Throws_WhenStatementFails()
    {
        var responseJson = """
        {
          "statement_id": "stmt-123",
          "status": {
            "state": "FAILED",
            "error": {
              "message": "Table not found"
            }
          },
          "manifest": {
            "schema": {
              "columns": []
            }
          }
        }
        """;

        var client = CreateClient(new StubHttpMessageHandler(responseJson));

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(
            () => client.QueryAsync("SELECT * FROM missing_table", CancellationToken.None));

        Assert.Contains("FAILED", exception.Message);
        Assert.Contains("Table not found", exception.Message);
    }

    [Fact]
    public async Task QueryAsync_Throws_WhenResultIsChunked()
    {
        var responseJson = """
        {
          "statement_id": "stmt-123",
          "status": {
            "state": "SUCCEEDED"
          },
          "manifest": {
            "schema": {
              "columns": [
                { "name": "league_id" }
              ]
            },
            "chunks": [
              { "chunk_index": 0, "row_offset": 0, "row_count": 1 },
              { "chunk_index": 1, "row_offset": 1, "row_count": 1 }
            ]
          },
          "result": {
            "data_array": [
              [ "135" ]
            ],
            "next_chunk_index": 1
          }
        }
        """;

        var client = CreateClient(new StubHttpMessageHandler(responseJson));

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(
            () => client.QueryAsync("SELECT * FROM table", CancellationToken.None));

        Assert.Contains("additional result chunks", exception.Message);
    }

    private static DatabricksStatementExecutionSqlClient CreateClient(HttpMessageHandler handler)
    {
        var httpClient = new HttpClient(handler);

        var options = MicrosoftOptions.Create(new DatabricksSqlOptions
        {
            WorkspaceUrl = "https://example.cloud.databricks.com",
            WarehouseId = "warehouse-123",
            AuthenticationType = "Token",
            AccessToken = "test-token"
        });

        return new DatabricksStatementExecutionSqlClient(httpClient, options);
    }

    private sealed class StubHttpMessageHandler(string responseJson) : HttpMessageHandler
    {
        public HttpRequestMessage? LastRequest { get; private set; }
        public string? LastRequestBody { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            LastRequest = request;

            if (request.Content is not null)
            {
                LastRequestBody = await request.Content.ReadAsStringAsync(cancellationToken);
            }

            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(responseJson, Encoding.UTF8, "application/json")
            };
        }
    }
}

