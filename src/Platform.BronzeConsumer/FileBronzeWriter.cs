using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace Platform.BronzeConsumer;

public sealed class FileBronzeWriter(
    string outputPath,
    RetryOptions retryOptions,
    ILogger<FileBronzeWriter> logger) : IBronzeWriter
{
    public async Task WriteAsync(BronzeRow bronzeRow, CancellationToken cancellationToken)
    {
        await RetryHelper.ExecuteAsync(
            async () =>
            {
                Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);

                var line = JsonSerializer.Serialize(bronzeRow);
                await File.AppendAllTextAsync(outputPath, line + Environment.NewLine, cancellationToken);
            },
            retryOptions,
            logger,
            "Write Bronze row",
            cancellationToken);
    }
}
