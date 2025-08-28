using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Npgsql;
using NpgsqlTypes;
using AuthContracts;
using System.Diagnostics;
using Microsoft.AspNetCore.Routing;

var builder = WebApplication.CreateBuilder(args);

// ENV'leri config'e ekle
builder.Configuration.AddEnvironmentVariables();

static string GetConn(IConfiguration cfg)
{
    var raw = Environment.GetEnvironmentVariable("IDENTITY_DB_CONN")
             ?? cfg["IDENTITY_DB_CONN"]
             ?? cfg.GetConnectionString("IdentityDb")
             ?? "";
    raw = raw.Replace("\u0000", "").Trim();
    if (!string.IsNullOrEmpty(raw) && raw[0] == '\uFEFF') raw = raw[1..].Trim();
    return raw;
}

builder.Services.AddSingleton<NpgsqlDataSource>(sp =>
{
    var cs = GetConn(sp.GetRequiredService<IConfiguration>());
    if (string.IsNullOrWhiteSpace(cs))
        throw new InvalidOperationException("IDENTITY_DB_CONN not set");
    return new NpgsqlDataSourceBuilder(cs).Build();
});

var app = builder.Build();

app.Use(async (ctx, next) =>
{
    // X-Request-Id varsa kullan, yoksa üret
    var reqId = ctx.Request.Headers.ContainsKey("X-Request-Id")
        && !string.IsNullOrWhiteSpace(ctx.Request.Headers["X-Request-Id"])
        ? ctx.Request.Headers["X-Request-Id"].ToString()
        : Guid.NewGuid().ToString("n");

    ctx.Response.Headers["X-Request-Id"] = reqId;

    var sw = Stopwatch.StartNew();
    try
    {
        await next();
        sw.Stop();
        var log = ctx.RequestServices.GetRequiredService<ILoggerFactory>()
                                     .CreateLogger("ReqLog");
        log.LogInformation("HTTP {m} {p} -> {s} ({ms} ms) rid={rid}",
            ctx.Request.Method, ctx.Request.Path, ctx.Response.StatusCode,
            sw.ElapsedMilliseconds, reqId);
    }
    catch (Exception ex)
    {
        sw.Stop();
        var log = ctx.RequestServices.GetRequiredService<ILoggerFactory>()
                                     .CreateLogger("ReqLog");
        log.LogError(ex, "HTTP {m} {p} FAILED ({ms} ms) rid={rid}",
            ctx.Request.Method, ctx.Request.Path, sw.ElapsedMilliseconds, reqId);
        throw;
    }
});

// küçük yardımcılar
static (IPAddress ip, string ua) Client(HttpContext ctx)
{
    var ip = ctx.Connection.RemoteIpAddress ?? IPAddress.Loopback;
    var ua = ctx.Request.Headers.UserAgent.ToString();
    if (string.IsNullOrWhiteSpace(ua)) ua = "api";
    return (ip, ua);
}

static IResult PgProblem(Npgsql.PostgresException e)
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
                           statusCode: 500,
                           type: $"pg:{e.SqlState}");
}

// health & debug
app.MapGet("/healthz", () => Results.Ok("OK"));

// --- METRICS (Prometheus düz metin) ---
app.MapGet("/metrics", (HttpContext ctx) =>
{
    ctx.Response.ContentType = "text/plain; charset=utf-8";
    var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

    var body =
$@"# HELP opas_identity_up Whether the identity api is up (1) or down (0)
# TYPE opas_identity_up gauge
opas_identity_up 1
# HELP opas_identity_build_info Build info
# TYPE opas_identity_build_info gauge
opas_identity_build_info{{version=""0.0.1""}} 1
# HELP opas_identity_last_scrape_ts Last scrape timestamp (unix)
# TYPE opas_identity_last_scrape_ts gauge
opas_identity_last_scrape_ts {now}
";
    return Results.Text(body, "text/plain");
});

// --- DEBUG/ROUTES: tüm kayıtlı rotaları gör ---
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


app.MapGet("/debug/conn", (IConfiguration cfg) =>
{
    var cs = GetConn(cfg);
    var preview = cs.Length <= 60 ? cs : $"{cs[..30]} ... {cs[^20..]}";
    return Results.Ok(new { length = cs.Length, preview });
});

app.MapGet("/db/ping", async (IConfiguration cfg) =>
{
    try
    {
        await using var conn = new NpgsqlConnection(GetConn(cfg));
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

// LOGIN  --> auth.fn_login_email_password(p_gln citext, p_email citext, p_password text, p_ip text, p_user_agent text)
app.MapPost("/auth/login", async (LoginReq req, NpgsqlDataSource db, HttpContext ctx) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();
        // Overload karışmasın diye cast’leri SQL’de zorluyoruz:
        await using var cmd = new NpgsqlCommand(
            "SELECT session_id, refresh_token " +
            "FROM auth.fn_login_email_password(@g::text, @e::citext, @p::text, @ip::inet, @ua::text)", conn);

        // Parametreleri düz TEXT veriyoruz; cast’i SQL tarafında yapıyoruz.
        cmd.Parameters.Add("g",  NpgsqlTypes.NpgsqlDbType.Text).Value  = req.gln;
        cmd.Parameters.Add("e",  NpgsqlTypes.NpgsqlDbType.Text).Value  = req.email;      // cast SQL'de
        cmd.Parameters.Add("p",  NpgsqlTypes.NpgsqlDbType.Text).Value  = req.password;
        cmd.Parameters.Add("ip", NpgsqlTypes.NpgsqlDbType.Inet).Value  = new NpgsqlTypes.NpgsqlInet(ctx.Connection.RemoteIpAddress ?? IPAddress.Loopback);
        cmd.Parameters.Add("ua", NpgsqlTypes.NpgsqlDbType.Text).Value  = ctx.Request.Headers.UserAgent.ToString() ?? "api";


        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return Results.Unauthorized();

        return Results.Ok(new { session_id = r.GetGuid(0), refresh_token = r.GetString(1) });
    }
    catch (Npgsql.PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex) { return Results.Problem(ex.Message); }
});


// REFRESH --> auth.fn_refresh(p_refresh_token text, p_ip text, p_user_agent text)
app.MapPost("/auth/refresh", async (RefreshReq req, NpgsqlDataSource db, HttpContext ctx) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT * FROM auth.fn_refresh(@rt,@ip,@ua)", conn);

        cmd.Parameters.Add("rt", NpgsqlDbType.Text).Value = req.refresh_token;

        var (ip, ua) = Client(ctx);
        cmd.Parameters.Add("ip", NpgsqlDbType.Text).Value = ip.ToString(); // <-- text, inet DEĞİL
        cmd.Parameters.Add("ua", NpgsqlDbType.Text).Value = ua;

        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return Results.Unauthorized();

        return Results.Ok(new { session_id = r.GetGuid(0), refresh_token = r.GetString(1) });
    }
    catch (Npgsql.PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex) { return Results.Problem(ex.Message); }
});

// CLAIMS --> auth.fn_session_claims(p_session_id uuid)
app.MapGet("/auth/claims", async (Guid sid, NpgsqlDataSource db) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT tenant_id, user_id, tenant_gln, roles FROM auth.fn_session_claims(@sid)", conn);

        cmd.Parameters.Add("sid", NpgsqlDbType.Uuid).Value = sid;

        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return Results.NotFound();

        return Results.Ok(new
        {
            tenant_id = r.GetGuid(0),
            user_id = r.GetGuid(1),
            tenant_gln = r.GetString(2),
            roles = r.GetFieldValue<string[]>(3)
        });
    }
    catch (Npgsql.PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex) { return Results.Problem(ex.Message); }
});

// LOGOUT --> auth.fn_logout(p_session_id uuid)
app.MapPost("/auth/logout", async (LogoutReq req, NpgsqlDataSource db) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT auth.fn_logout(@sid)", conn);
        cmd.Parameters.Add("sid", NpgsqlDbType.Uuid).Value = req.sid;
        await cmd.ExecuteNonQueryAsync();
        return Results.NoContent();
    }
    catch (Npgsql.PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex) { return Results.Problem(ex.Message); }
});

app.Run();
