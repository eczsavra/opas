using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Npgsql;
using NpgsqlTypes;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// ENV'leri config'e ekle
builder.Configuration.AddEnvironmentVariables();

// Npgsql DataSource
builder.Services.AddSingleton<NpgsqlDataSource>(sp =>
{
    var cs = Helpers.GetConn(sp.GetRequiredService<IConfiguration>());
    if (string.IsNullOrWhiteSpace(cs))
        throw new InvalidOperationException("IDENTITY_DB_CONN not set");
    return new NpgsqlDataSourceBuilder(cs).Build();
});

var app = builder.Build();

// Health
app.MapGet("/healthz", () => Results.Ok("OK"));

// Prometheus
app.UseHttpMetrics();
app.MapMetrics("/metrics");

// Debug: rotalar
app.MapGet("/debug/routes", (IEnumerable<EndpointDataSource> sources) =>
{
    var routes = sources
        .SelectMany(s => s.Endpoints)
        .OfType<RouteEndpoint>()
        .Select(e => e.RoutePattern.RawText)
        .OrderBy(x => x)
        .ToArray();
    return Results.Ok(routes);
});

// Debug: bağlantı string önizleme
app.MapGet("/debug/conn", (IConfiguration cfg) =>
{
    var cs = Helpers.GetConn(cfg);
    var preview = cs.Length <= 60 ? cs : $"{cs[..30]} ... {cs[^20..]}";
    return Results.Ok(new { length = cs.Length, preview });
});

// DB ping
app.MapGet("/db/ping", async (IConfiguration cfg) =>
{
    try
    {
        await using var conn = new NpgsqlConnection(Helpers.GetConn(cfg));
        await conn.OpenAsync();
        await using var cmd = new NpgsqlCommand("select 1", conn);
        var x = await cmd.ExecuteScalarAsync();
        return Results.Ok(new { ok = true, result = x });
    }
    catch (Exception ex)
    {
        return Results.Problem($"db open failed: {ex.Message}");
    }
});

// API endpointlerini ayrı sınıfa bağla
app.MapIdentityApi();

// up metriğini 1 yap
AppMetrics.Up.Set(1);

app.Run();

// ---------------- Types ----------------

static class AppMetrics
{
    public static readonly Gauge Up =
        Metrics.CreateGauge("opas_identity_up", "Whether the identity api is up (1) or down (0)");

    public static readonly Counter LoginTotal =
        Metrics.CreateCounter("opas_identity_login_total", "Toplam login denemeleri",
            new CounterConfiguration { LabelNames = new[] { "result" } });
}

static class Helpers
{
    public static string GetConn(IConfiguration cfg)
    {
        var raw = Environment.GetEnvironmentVariable("IDENTITY_DB_CONN")
                 ?? cfg["IDENTITY_DB_CONN"]
                 ?? cfg.GetConnectionString("IdentityDb")
                 ?? "";
        raw = raw.Replace("\u0000", "").Trim();
        if (!string.IsNullOrEmpty(raw) && raw[0] == '\uFEFF') raw = raw[1..].Trim();
        return raw;
    }

    public static (IPAddress ip, string ua) Client(HttpContext ctx)
    {
        var ip = ctx.Connection.RemoteIpAddress ?? IPAddress.Loopback;
        var ua = ctx.Request.Headers.UserAgent.ToString();
        if (string.IsNullOrWhiteSpace(ua)) ua = "api";
        return (ip, ua);
    }

    public static IResult PgProblem(Npgsql.PostgresException e)
    {
        var detail = new
        {
            sqlstate = e.SqlState,
            message = e.MessageText,
            table = e.TableName,
            schema = e.SchemaName,
            routine = e.Routine,
            hint = e.Hint,
            position = e.Position
        };
        return Results.Problem(title: "Postgres error",
            detail: System.Text.Json.JsonSerializer.Serialize(detail),
            statusCode: 500, type: $"pg:{e.SqlState}");
    }
}
