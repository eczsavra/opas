using Microsoft.AspNetCore.Http;
using System.Net;
using System.Text.Json;
using Npgsql;

namespace Identity.Api;

public static class Helpers
{
    // Var olan kullanımları kırmamak için iki isim de mevcut:
    public static (string ip, string ua) GetClient(HttpRequest req)
    {
        var ip = (req.HttpContext.Connection.RemoteIpAddress ?? IPAddress.Loopback).ToString();

        // Header: User-Agent (case-insensitive). .UserAgent varsa onu, yoksa klasik header anahtarını oku
        var ua = req.Headers.UserAgent.ToString();
        if (string.IsNullOrEmpty(ua) && req.Headers.TryGetValue("User-Agent", out var uaVal))
            ua = uaVal.ToString();

        return (ip, ua ?? string.Empty);
    }

    // Eski kodla uyumlu takma ad
    public static (string ip, string ua) Client(HttpRequest req) => GetClient(req);

    // Npgsql.PostgresException -> RFC7807 ProblemDetails
    public static IResult PgProblem(Exception ex, int statusCode = 500)
    {
        if (ex is PostgresException pg)
        {
            var detailObj = new
            {
                sqlstate = pg.SqlState,
                message  = pg.MessageText,
                table    = pg.TableName,
                schema   = pg.SchemaName,
                routine  = pg.Routine,
                hint     = pg.Hint,
                position = pg.Position
            };

            return Results.Problem(
                type: $"pg:{pg.SqlState}",
                title: "Postgres error",
                statusCode: statusCode,
                detail: JsonSerializer.Serialize(detailObj)
            );
        }

        return Results.Problem(title: ex.Message, statusCode: statusCode);
    }
}
