using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Platform.Api.Options;

namespace Platform.Api.Infrastructure.Databricks;

public sealed class DatabricksStatementExecutionSqlClient(
    HttpClient httpClient,
    IOptions<DatabricksSqlOptions> options) : IDatabricksSqlClient
{
    private readonly HttpClient _httpClient = httpClient;
    private readonly DatabricksSqlOptions _options = options.Value;

    public async Task<IReadOnlyList<DatabricksSqlRow>> QueryAsync(
        string sql,
        CancellationToken cancellationToken)
    {
        if (_options.AuthenticationType.Equals("Stub", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Databricks SQL client is configured in Stub mode. Use the stub client registration for local development.");
        }

        if (string.IsNullOrWhiteSpace(_options.WorkspaceUrl))
        {
            throw new InvalidOperationException("DatabricksSql:WorkspaceUrl is required.");
        }

        if (string.IsNullOrWhiteSpace(_options.WarehouseId))
        {
            throw new InvalidOperationException("DatabricksSql:WarehouseId is required.");
        }

        if (string.IsNullOrWhiteSpace(_options.AccessToken))
        {
            throw new InvalidOperationException("DatabricksSql:AccessToken is required for token-based authentication.");
        }

        var requestUri = $"{_options.WorkspaceUrl.TrimEnd('/')}/api/2.0/sql/statements/";

        using var request = new HttpRequestMessage(HttpMethod.Post, requestUri);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.AccessToken);

        var payload = new
        {
            statement = sql,
            warehouse_id = _options.WarehouseId,
            wait_timeout = "10s",
            disposition = "INLINE",
            format = "JSON_ARRAY"
        };

        request.Content = new StringContent(
            JsonSerializer.Serialize(payload),
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        var responseJson = await response.Content.ReadAsStringAsync(cancellationToken);

        // Placeholder: in the real implementation, parse the Statement Execution API
        // response and map rows into DatabricksSqlRow instances.
        throw new NotImplementedException(
            $"Statement Execution call succeeded but row parsing is not implemented yet. Raw response: {responseJson}");
    }
}

