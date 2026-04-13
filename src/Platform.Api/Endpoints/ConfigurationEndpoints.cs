using Microsoft.Extensions.Options;
using Platform.Api.Options;

namespace Platform.Api.Endpoints;

public static class ConfigurationEndpoints
{
    public static IEndpointRouteBuilder MapConfigurationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/config/sources", (IOptions<SourceOptions> options) =>
            {
                var config = options.Value;

                return Results.Ok(new
                {
                    primary = config.Primary,
                    supportedLeagues = config.SupportedLeagues,
                    activeLeagueIds = config.ActiveLeagueIds,
                    season = config.Season
                });
            })
            .WithName("GetSourceConfiguration")
            .WithSummary("Get configured source settings")
            .WithDescription("Returns the currently configured source metadata exposed by the API.")
            .WithTags("Configuration")
            .Produces(StatusCodes.Status200OK);

        return app;
    }
}
