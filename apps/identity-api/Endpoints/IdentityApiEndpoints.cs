using System.Net;
using Npgsql;
using NpgsqlTypes;
using Prometheus;
using AuthContracts;
using Identity.Api;

public static class IdentityApiEndpoints
{
    public static IEndpointRouteBuilder MapIdentityApi(this IEndpointRouteBuilder app)
    {
        // LOGIN
        app.MapPost("/auth/login", async (LoginReq req, NpgsqlDataSource db, HttpContext ctx) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT session_id, refresh_token " +
            "FROM auth.fn_login_email_password(@g::text, @e::citext, @p::text, @ip::inet, @ua::text)", conn);

        cmd.Parameters.Add("g",  NpgsqlDbType.Text).Value = req.gln;
        cmd.Parameters.Add("e",  NpgsqlDbType.Text).Value = req.email;
        cmd.Parameters.Add("p",  NpgsqlDbType.Text).Value = req.password;

        // IP/UA
        var ip = (ctx.Connection.RemoteIpAddress ?? IPAddress.Loopback).ToString();
        var ua = ctx.Request.Headers["User-Agent"].ToString();
        if (string.IsNullOrWhiteSpace(ua)) ua = "api";

        cmd.Parameters.Add("ip", NpgsqlDbType.Text).Value = ip; // "::inet" cast SQL tarafında
        cmd.Parameters.Add("ua", NpgsqlDbType.Text).Value = ua;

        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync())
        {
            AppMetrics.LoginTotal.WithLabels("fail").Inc();
            return Results.Unauthorized();
        }

        AppMetrics.LoginTotal.WithLabels("success").Inc();
        var sid = r.GetGuid(0);
        var rt  = r.GetString(1);

        // Şimdilik sahte access token — sadece 200’ü görelim
        return Results.Json(new LoginResponse(sid, rt, "dev_access_token", 600));
    }
    catch (PostgresException pe)
    {
        AppMetrics.LoginTotal.WithLabels("error").Inc();
        return Helpers.PgProblem(pe);
    }
    catch (Exception ex)
    {
        AppMetrics.LoginTotal.WithLabels("error").Inc();
        return Results.Problem(ex.Message);
    }
});

        // REFRESH
        app.MapPost("/auth/refresh", async (RefreshReq req, NpgsqlDataSource db, HttpContext ctx) =>
        {
            try
            {
                await using var conn = await db.OpenConnectionAsync();
                await using var cmd = new NpgsqlCommand("SELECT * FROM auth.fn_refresh(@rt,@ip,@ua)", conn);

                cmd.Parameters.Add("rt", NpgsqlDbType.Text).Value = req.refresh_token;

                var (ip, ua) = Helpers.Client(ctx.Request);
                cmd.Parameters.Add("ip", NpgsqlDbType.Text).Value = ip.ToString();
                cmd.Parameters.Add("ua", NpgsqlDbType.Text).Value = ua;

                await using var r = await cmd.ExecuteReaderAsync();
                if (!await r.ReadAsync()) return Results.Unauthorized();

                var sid = r.GetGuid(0);
                var rt = r.GetString(1);
                var accessToken = "temp_access_token"; // TODO: Implement JWT generation
                return Results.Json(new RefreshResponse(sid, rt, accessToken, 600));
            }
            catch (PostgresException pe) { return Helpers.PgProblem(pe); }
            catch (Exception ex) { return Results.Problem(ex.Message); }
        });

        // CLAIMS
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
            catch (PostgresException pe) { return Helpers.PgProblem(pe); }
            catch (Exception ex) { return Results.Problem(ex.Message); }
        });

        // LOGOUT
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
            catch (PostgresException pe) { return Helpers.PgProblem(pe); }
            catch (Exception ex) { return Results.Problem(ex.Message); }
        });

        return app;
    }
}


