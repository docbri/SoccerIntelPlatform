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
            });

        return app;
    }
}

