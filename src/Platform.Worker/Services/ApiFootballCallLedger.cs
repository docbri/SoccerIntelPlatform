using System.Text.Json;

namespace Platform.Worker.Services;

public sealed class ApiFootballCallLedger(ILogger<ApiFootballCallLedger> logger)
{
    private readonly ILogger<ApiFootballCallLedger> _logger = logger;

    private static readonly JsonSerializerOptions JsonSerializerOptions = new()
    {
        WriteIndented = true
    };

    public async Task<bool> TryReserveCallAsync(
        int maxCallsPerDay,
        CancellationToken cancellationToken)
    {
        var ledger = await ReadLedgerAsync(cancellationToken);
        var todayUtc = DateOnly.FromDateTime(DateTime.UtcNow).ToString("yyyy-MM-dd");

        if (!string.Equals(ledger.DateUtc, todayUtc, StringComparison.Ordinal))
        {
            ledger = new ApiFootballCallLedgerState
            {
                DateUtc = todayUtc,
                CallsMade = 0,
                MaxCallsPerDay = maxCallsPerDay
            };
        }

        ledger.MaxCallsPerDay = maxCallsPerDay;

        if (ledger.CallsMade >= maxCallsPerDay)
        {
            _logger.LogWarning(
                "API-Football daily call limit reached. CallsMade={CallsMade}, MaxCallsPerDay={MaxCallsPerDay}, DateUtc={DateUtc}",
                ledger.CallsMade,
                maxCallsPerDay,
                todayUtc);

            return false;
        }

        ledger.CallsMade++;
        ledger.LastCallStartedAtUtc = DateTime.UtcNow;

        await WriteLedgerAsync(ledger, cancellationToken);

        _logger.LogInformation(
            "Reserved API-Football call {CallsMade}/{MaxCallsPerDay} for {DateUtc}.",
            ledger.CallsMade,
            maxCallsPerDay,
            todayUtc);

        return true;
    }

    public async Task MarkCallCompletedAsync(CancellationToken cancellationToken)
    {
        var ledger = await ReadLedgerAsync(cancellationToken);
        ledger.LastCallCompletedAtUtc = DateTime.UtcNow;
        await WriteLedgerAsync(ledger, cancellationToken);
    }

    private static string ResolveLedgerPath()
    {
        var configuredPath = Environment.GetEnvironmentVariable("API_FOOTBALL_CALL_LEDGER_PATH");

        if (!string.IsNullOrWhiteSpace(configuredPath))
        {
            return configuredPath;
        }

        return Path.Combine(
            Directory.GetCurrentDirectory(),
            "localdata",
            "api-football-call-ledger.json");
    }

    private static async Task<ApiFootballCallLedgerState> ReadLedgerAsync(CancellationToken cancellationToken)
    {
        var ledgerPath = ResolveLedgerPath();

        if (!File.Exists(ledgerPath))
        {
            return new ApiFootballCallLedgerState
            {
                DateUtc = DateOnly.FromDateTime(DateTime.UtcNow).ToString("yyyy-MM-dd")
            };
        }

        await using var stream = File.OpenRead(ledgerPath);

        var ledger = await JsonSerializer.DeserializeAsync<ApiFootballCallLedgerState>(
            stream,
            JsonSerializerOptions,
            cancellationToken);

        return ledger ?? new ApiFootballCallLedgerState
        {
            DateUtc = DateOnly.FromDateTime(DateTime.UtcNow).ToString("yyyy-MM-dd")
        };
    }

    private static async Task WriteLedgerAsync(
        ApiFootballCallLedgerState ledger,
        CancellationToken cancellationToken)
    {
        var ledgerPath = ResolveLedgerPath();
        var ledgerDirectory = Path.GetDirectoryName(ledgerPath);

        if (!string.IsNullOrWhiteSpace(ledgerDirectory))
        {
            Directory.CreateDirectory(ledgerDirectory);
        }

        await using var stream = File.Create(ledgerPath);

        await JsonSerializer.SerializeAsync(
            stream,
            ledger,
            JsonSerializerOptions,
            cancellationToken);
    }

    private sealed class ApiFootballCallLedgerState
    {
        public string DateUtc { get; set; } = DateOnly.FromDateTime(DateTime.UtcNow).ToString("yyyy-MM-dd");
        public int CallsMade { get; set; }
        public int MaxCallsPerDay { get; set; }
        public DateTime? LastCallStartedAtUtc { get; set; }
        public DateTime? LastCallCompletedAtUtc { get; set; }
    }
}
