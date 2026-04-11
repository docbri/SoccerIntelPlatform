namespace Platform.Api.Endpoints;

public static class HealthEndpoints
{
    public static IEndpointRouteBuilder MapHealthEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/health", () =>
        {
            return Results.Ok(new
            {
                status = "Healthy",
                service = "Platform.Api",
                utc = DateTime.UtcNow
            });
        });

        return app;
    }
}
