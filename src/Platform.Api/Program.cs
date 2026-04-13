using Platform.Api.Endpoints;
using Platform.Api.Infrastructure.Databricks;
using Platform.Api.Options;
using Platform.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddOptions<SourceOptions>()
    .Bind(builder.Configuration.GetSection(SourceOptions.SectionName));

builder.Services
    .AddOptions<DatabricksSqlOptions>()
    .Bind(builder.Configuration.GetSection(DatabricksSqlOptions.SectionName));

builder.Services.AddHttpClient<DatabricksStatementExecutionSqlClient>();

builder.Services.AddSingleton<IDatabricksSqlClient, StubDatabricksSqlClient>();
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
app.MapConfigurationEndpoints();
app.MapLeagueStatusEndpoints();

app.Run();

public partial class Program { }
