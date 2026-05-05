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
        ValidateOptions();

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
        var responseJson = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"Databricks SQL statement request failed with HTTP {(int)response.StatusCode} {response.ReasonPhrase}. Response: {responseJson}");
        }

        return ParseInlineJsonArrayResponse(responseJson);
    }

    private void ValidateOptions()
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
    }

    private static IReadOnlyList<DatabricksSqlRow> ParseInlineJsonArrayResponse(string responseJson)
    {
        using var document = JsonDocument.Parse(responseJson);
        var root = document.RootElement;

        var state = ReadStatementState(root);

        if (!string.Equals(state, "SUCCEEDED", StringComparison.OrdinalIgnoreCase))
        {
            var errorMessage = ReadStatementErrorMessage(root);

            throw new InvalidOperationException(
                $"Databricks SQL statement did not succeed. State: {state}. Error: {errorMessage}");
        }

        var columnNames = ReadColumnNames(root);

        if (HasMoreResultChunks(root))
        {
            throw new InvalidOperationException(
                "Databricks SQL statement returned additional result chunks. Chunked result handling is not supported in this first API integration slice.");
        }

        if (!root.TryGetProperty("result", out var result) ||
            !result.TryGetProperty("data_array", out var dataArray) ||
            dataArray.ValueKind == JsonValueKind.Null)
        {
            return [];
        }

        if (dataArray.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidOperationException("Databricks SQL response result.data_array was not an array.");
        }

        var rows = new List<DatabricksSqlRow>();

        foreach (var rowElement in dataArray.EnumerateArray())
        {
            if (rowElement.ValueKind != JsonValueKind.Array)
            {
                throw new InvalidOperationException("Databricks SQL response row was not an array.");
            }

            var values = rowElement.EnumerateArray().ToArray();

            if (values.Length != columnNames.Count)
            {
                throw new InvalidOperationException(
                    $"Databricks SQL response row column count mismatch. Expected {columnNames.Count}, received {values.Length}.");
            }

            var row = new DatabricksSqlRow();

            for (var i = 0; i < columnNames.Count; i++)
            {
                row.Values[columnNames[i]] = ConvertJsonValue(values[i]);
            }

            rows.Add(row);
        }

        return rows;
    }

    private static string ReadStatementState(JsonElement root)
    {
        if (!root.TryGetProperty("status", out var status) ||
            !status.TryGetProperty("state", out var stateElement) ||
            stateElement.ValueKind != JsonValueKind.String)
        {
            throw new InvalidOperationException("Databricks SQL response did not contain status.state.");
        }

        return stateElement.GetString() ?? string.Empty;
    }

    private static string ReadStatementErrorMessage(JsonElement root)
    {
        if (root.TryGetProperty("status", out var status) &&
            status.TryGetProperty("error", out var error) &&
            error.TryGetProperty("message", out var message) &&
            message.ValueKind == JsonValueKind.String)
        {
            return message.GetString() ?? string.Empty;
        }

        return "No error message returned.";
    }

    private static IReadOnlyList<string> ReadColumnNames(JsonElement root)
    {
        if (!root.TryGetProperty("manifest", out var manifest) ||
            !manifest.TryGetProperty("schema", out var schema) ||
            !schema.TryGetProperty("columns", out var columns) ||
            columns.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidOperationException("Databricks SQL response did not contain manifest.schema.columns.");
        }

        var columnNames = new List<string>();

        foreach (var column in columns.EnumerateArray())
        {
            if (!column.TryGetProperty("name", out var nameElement) ||
                nameElement.ValueKind != JsonValueKind.String)
            {
                throw new InvalidOperationException("Databricks SQL response contained a column without a name.");
            }

            var name = nameElement.GetString();

            if (string.IsNullOrWhiteSpace(name))
            {
                throw new InvalidOperationException("Databricks SQL response contained a blank column name.");
            }

            columnNames.Add(name);
        }

        return columnNames;
    }

    private static bool HasMoreResultChunks(JsonElement root)
    {
        if (root.TryGetProperty("result", out var result) &&
            result.TryGetProperty("next_chunk_index", out var nextChunkIndex) &&
            nextChunkIndex.ValueKind != JsonValueKind.Null)
        {
            return true;
        }

        if (root.TryGetProperty("manifest", out var manifest) &&
            manifest.TryGetProperty("chunks", out var chunks) &&
            chunks.ValueKind == JsonValueKind.Array &&
            chunks.GetArrayLength() > 1)
        {
            return true;
        }

        return false;
    }

    private static object? ConvertJsonValue(JsonElement value)
    {
        return value.ValueKind switch
        {
            JsonValueKind.Null => null,
            JsonValueKind.String => value.GetString(),
            JsonValueKind.Number => value.GetRawText(),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            _ => value.GetRawText()
        };
    }
}
