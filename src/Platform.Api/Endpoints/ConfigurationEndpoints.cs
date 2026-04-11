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
        });

        return app;
    }
}
