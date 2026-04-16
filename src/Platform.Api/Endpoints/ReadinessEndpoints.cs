using Platform.Api.Contracts;
using Platform.Api.Infrastructure.Databricks;

namespace Platform.Api.Endpoints;

public static class ReadinessEndpoints
{
    private static readonly TimeSpan ReadinessTimeout = TimeSpan.FromSeconds(5);

    public static IEndpointRouteBuilder MapReadinessEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/ready",
                async (
                    IDatabricksSqlClient databricksSqlClient,
                    ILoggerFactory loggerFactory,
                    CancellationToken cancellationToken) =>
                {
                    var logger = loggerFactory.CreateLogger("Platform.Api.Readiness");
                    var checks = new List<ReadinessCheck>();

                    var databricksCheck = await RunDatabricksCheckAsync(
                        databricksSqlClient,
                        logger,
                        cancellationToken);

                    checks.Add(databricksCheck);

                    var allOk = checks.TrueForAll(c => c.Ok);

                    var response = new ReadinessResponse
                    {
                        Status = allOk ? "Ready" : "NotReady",
                        Utc = DateTime.UtcNow,
                        Checks = checks
                    };

                    return allOk
                        ? Results.Ok(response)
                        : Results.Json(response, statusCode: StatusCodes.Status503ServiceUnavailable);
                })
            .WithName("GetReadiness")
            .WithSummary("Get API readiness status")
            .WithDescription("Reports whether the API can serve traffic by verifying downstream dependencies.")
            .WithTags("Health")
            .Produces<ReadinessResponse>(StatusCodes.Status200OK)
            .Produces<ReadinessResponse>(StatusCodes.Status503ServiceUnavailable);

        return app;
    }

    private static async Task<ReadinessCheck> RunDatabricksCheckAsync(
        IDatabricksSqlClient client,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(ReadinessTimeout);

        try
        {
            _ = await client.QueryAsync("SELECT 1", cts.Token);
            return new ReadinessCheck { Name = "databricks", Ok = true };
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Readiness check failed for databricks");
            return new ReadinessCheck
            {
                Name = "databricks",
                Ok = false,
                Error = ex.GetType().Name
            };
        }
    }
}
