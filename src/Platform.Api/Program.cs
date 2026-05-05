using Platform.Api.Endpoints;
using Platform.Api.Infrastructure.Databricks;
using Platform.Api.Options;
using Platform.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Options
builder.Services
    .AddOptions<SourceOptions>()
    .Bind(builder.Configuration.GetSection(SourceOptions.SectionName));

builder.Services
    .AddOptions<DatabricksSqlOptions>()
    .Bind(builder.Configuration.GetSection(DatabricksSqlOptions.SectionName));

builder.Services
    .AddOptions<ReadinessOptions>()
    .Bind(builder.Configuration.GetSection(ReadinessOptions.SectionName));

// Http client for real Databricks SQL client
builder.Services.AddHttpClient<DatabricksStatementExecutionSqlClient>();

// Conditional SQL client registration (Section H ready, Section A compatible)
builder.Services.AddSingleton<IDatabricksSqlClient>(sp =>
{
    var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<DatabricksSqlOptions>>().Value;

    return options.AuthenticationType switch
    {
        "Stub" => new StubDatabricksSqlClient(),
        _ => sp.GetRequiredService<DatabricksStatementExecutionSqlClient>()
    };
});

// Services
builder.Services.AddSingleton<ILeagueStatusReadService, LeagueStatusReadService>();

builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();

    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "Platform.Api v1");
    });
}

app.MapHealthEndpoints();
app.MapReadinessEndpoints();
app.MapConfigurationEndpoints();
app.MapLeagueStatusEndpoints();

app.Run();

public partial class Program { }
