using System.Net;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using NpgsqlTypes;
using Prometheus;
using AuthContracts;

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

                cmd.Parameters.Add("g",  NpgsqlDbType.Text).Value  = req.gln;
                cmd.Parameters.Add("e",  NpgsqlDbType.Text).Value  = req.email;
                cmd.Parameters.Add("p",  NpgsqlDbType.Text).Value  = req.password;
                cmd.Parameters.Add("ip", NpgsqlDbType.Inet).Value  = new NpgsqlInet(ctx.Connection.RemoteIpAddress ?? IPAddress.Loopback);
                cmd.Parameters.Add("ua", NpgsqlDbType.Text).Value  = ctx.Request.Headers.UserAgent.ToString() ?? "api";

                await using var r = await cmd.ExecuteReaderAsync();
                if (!await r.ReadAsync())
                {
                    AppMetrics.LoginTotal.WithLabels("fail").Inc();
                    return Results.Unauthorized();
                }

                AppMetrics.LoginTotal.WithLabels("success").Inc();
                return Results.Ok(new { session_id = r.GetGuid(0), refresh_token = r.GetString(1) });
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

                var (ip, ua) = Helpers.Client(ctx);
                cmd.Parameters.Add("ip", NpgsqlDbType.Text).Value = ip.ToString();
                cmd.Parameters.Add("ua", NpgsqlDbType.Text).Value = ua;

                await using var r = await cmd.ExecuteReaderAsync();
                if (!await r.ReadAsync()) return Results.Unauthorized();

                return Results.Ok(new { session_id = r.GetGuid(0), refresh_token = r.GetString(1) });
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
