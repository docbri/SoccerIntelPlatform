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
            })
            .WithName("GetHealth")
            .WithSummary("Get API health status")
            .WithDescription("Returns a lightweight health response for deployment verification and availability checks.")
            .WithTags("Health")
            .Produces(StatusCodes.Status200OK);

        return app;
    }
}
