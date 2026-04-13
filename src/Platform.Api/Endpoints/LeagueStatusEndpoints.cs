using Platform.Api.Contracts;
using Platform.Api.Services;

namespace Platform.Api.Endpoints;

public static class LeagueStatusEndpoints
{
    public static IEndpointRouteBuilder MapLeagueStatusEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/league-status/current",
                async (
                    int? leagueId,
                    int? season,
                    ILeagueStatusReadService service,
                    CancellationToken cancellationToken) =>
                {
                    var result = await service.GetCurrentStatusesAsync(leagueId, season, cancellationToken);
                    return Results.Ok(result);
                })
            .WithName("GetCurrentLeagueStatus")
            .WithSummary("Get current league status")
            .WithDescription("Returns the latest league status records. Optional query parameters can filter by leagueId and season.")
            .WithTags("League Status")
            .Produces<IReadOnlyList<CurrentLeagueStatusResponse>>(StatusCodes.Status200OK);

        return app;
    }
}
