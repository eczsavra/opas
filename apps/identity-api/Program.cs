using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Npgsql;
using NpgsqlTypes;
using AuthContracts;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);


// ENV'leri config'e ekle

// --- CONFIG HELPERS ---
// --- CONFIG HELPERS ---
static string GetConn(IConfiguration cfg)
{
    var raw =
        cfg.GetConnectionString("IdentityDb") // 1) appsettings(.Development).json
        ?? cfg["IDENTITY_DB_CONN"]            // 2) config key
        ?? Environment.GetEnvironmentVariable("IDENTITY_DB_CONN") // 3) ENV (en sonda)
        ?? "";
    raw = raw.Replace("\u0000", "").Trim();
    if (!string.IsNullOrEmpty(raw) && raw[0] == '\uFEFF') raw = raw[1..].Trim();
    return raw;
}


string issuer   = builder.Configuration["IDENTITY_JWT_ISSUER"]   ?? "http://localhost:7001";
string audience = builder.Configuration["IDENTITY_JWT_AUDIENCE"] ?? "opas";
int    ttlMin   = int.TryParse(builder.Configuration["IDENTITY_ACCESS_TOKEN_TTL_MIN"], out var m) ? m : 15;

// --- DB ---
builder.Services.AddSingleton<NpgsqlDataSource>(sp =>
{
    var cs = GetConn(sp.GetRequiredService<IConfiguration>());
    if (string.IsNullOrWhiteSpace(cs))
        throw new InvalidOperationException("IDENTITY_DB_CONN not set");
    return new NpgsqlDataSourceBuilder(cs).Build();
});

// DEV: Ephemeral RSA key (sadece geliştirme için)
    var rsa = RSA.Create(2048);
    var rsaKey = new RsaSecurityKey(rsa) { KeyId = Guid.NewGuid().ToString("N") };

builder.Services.AddSingleton<RSA>(rsa);
builder.Services.AddSingleton<RsaSecurityKey>(rsaKey);

// --- JWT ISSUER (RSA) ---
builder.Services.AddSingleton(sp =>
{
    var cfg = sp.GetRequiredService<IConfiguration>();
    var pem = cfg["IDENTITY_JWT_PRIVATE_KEY_PEM"]; // opsiyonel; yoksa ephemeral üretiriz
    return JwtIssuer.Create(issuer, audience, ttlMin, pem);
});

var app = builder.Build();

// --- küçük yardımcılar ---
static (IPAddress ip, string ua) Client(HttpContext ctx)
{
    var ip = ctx.Connection.RemoteIpAddress ?? IPAddress.Loopback;
    var ua = ctx.Request.Headers.UserAgent.ToString();
    if (string.IsNullOrWhiteSpace(ua)) ua = "api";
    return (ip, ua);
}

static IResult PgProblem(PostgresException e)
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
                           detail: JsonSerializer.Serialize(detail),
                           statusCode: 500,
                           type: $"pg:{e.SqlState}");
}

// --- health & debug ---
app.MapGet("/healthz", () => Results.Ok("OK"));

app.MapGet("/debug/conn", (IConfiguration cfg) =>
{
    var cs = GetConn(cfg);
    var preview = cs.Length <= 60 ? cs : $"{cs[..30]} ... {cs[^20..]}";
    return Results.Ok(new { length = cs.Length, preview });
});

app.MapGet("/db/ping", async (NpgsqlDataSource db) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand("select 1", conn);
        var x = await cmd.ExecuteScalarAsync();
        return Results.Ok(new { ok = true, result = x });
    }
    catch (Exception ex)
    {
        return Results.Problem($"db open failed: {ex.Message}");
    }
});

// --- WELL-KNOWN (JWKS + minimal discovery) ---
app.MapGet("/.well-known/jwks.json", (JwtIssuer jwt) =>
{
    return Results.Json(new { keys = new[] { jwt.Jwk } });
});

app.MapGet("/.well-known/openid-configuration", (HttpContext ctx, JwtIssuer jwt) =>
{
    var baseUrl = jwt.Issuer.TrimEnd('/');
    return Results.Json(new
    {
        issuer = jwt.Issuer,
        jwks_uri = $"{baseUrl}/.well-known/jwks.json",
        token_endpoint = $"{baseUrl}/auth/login",
        grant_types_supported = new[] { "password", "refresh_token" },
        id_token_signing_alg_values_supported = new[] { "RS256" }
    });
});


// --- AUTH ENDPOINTS ---
// LOGIN  --> auth.fn_login_email_password(p_gln citext, p_email citext, p_password text, p_ip inet, p_user_agent text)
app.MapPost("/auth/login", async (LoginReq req, NpgsqlDataSource db, HttpContext ctx, JwtIssuer jwt) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();

        // 1) login -> session_id, refresh_token
        await using (var cmd = new NpgsqlCommand(
            "SELECT session_id, refresh_token " +
            "FROM auth.fn_login_email_password(@g::text, @e::citext, @p::text, @ip::inet, @ua::text)", conn))
        {
            cmd.Parameters.Add("g",  NpgsqlDbType.Text).Value = req.gln;
            cmd.Parameters.Add("e",  NpgsqlDbType.Text).Value = req.email;
            cmd.Parameters.Add("p",  NpgsqlDbType.Text).Value = req.password;
            cmd.Parameters.Add("ip", NpgsqlDbType.Inet).Value = new NpgsqlInet(ctx.Connection.RemoteIpAddress ?? IPAddress.Loopback);
            cmd.Parameters.Add("ua", NpgsqlDbType.Text).Value = ctx.Request.Headers.UserAgent.ToString() ?? "api";

            await using var r = await cmd.ExecuteReaderAsync();
            if (!await r.ReadAsync()) return Results.Unauthorized();
            var sessionId = r.GetGuid(0);
            var refresh   = r.GetString(1);

            // 2) claims -> JWT
            var claims = await GetClaimsAsync(conn, sessionId);
            if (claims is null) return Results.Unauthorized();

            var (token, exp) = jwt.Issue(claims.Value.user_id, claims.Value.tenant_id, claims.Value.tenant_gln, claims.Value.roles);

            return Results.Ok(new
            {
                access_token = token,
                token_type   = "Bearer",
                expires_in   = exp,
                refresh_token = refresh,
                session_id   = sessionId
            });
        }
    }
    catch (PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex)         { return Results.Problem(ex.Message); }
});

// REFRESH --> auth.fn_refresh(p_refresh_token text, p_ip text, p_user_agent text)  (DB tarafını düzelttik)
app.MapPost("/auth/refresh", async (RefreshReq req, NpgsqlDataSource db, HttpContext ctx, JwtIssuer jwt) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();

        // 1) rotate -> new session + new RT
        Guid newSid;
        string newRt;
        await using (var cmd = new NpgsqlCommand(
            "SELECT session_id, refresh_token FROM auth.fn_refresh(@rt, @ip, @ua)", conn))
        {
            cmd.Parameters.Add("rt", NpgsqlDbType.Text).Value = req.refresh_token ?? (object)DBNull.Value;
            var (ip, ua) = Client(ctx);
            cmd.Parameters.Add("ip", NpgsqlDbType.Text).Value = ip.ToString(); // function text bekliyor
            cmd.Parameters.Add("ua", NpgsqlDbType.Text).Value = ua;

            await using var r = await cmd.ExecuteReaderAsync();
            if (!await r.ReadAsync()) return Results.Unauthorized();
            newSid = r.GetGuid(0);
            newRt  = r.GetString(1);
        }

        // 2) claims -> JWT
        var claims = await GetClaimsAsync(conn, newSid);
        if (claims is null) return Results.Unauthorized();

        var (token, exp) = jwt.Issue(claims.Value.user_id, claims.Value.tenant_id, claims.Value.tenant_gln, claims.Value.roles);

        return Results.Ok(new
        {
            access_token = token,
            token_type   = "Bearer",
            expires_in   = exp,
            refresh_token = newRt,
            session_id   = newSid
        });
    }
    catch (PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex)         { return Results.Problem(ex.Message); }
});

// CLAIMS --> auth.fn_session_claims(p_session_id uuid)
app.MapGet("/auth/claims", async (Guid sid, NpgsqlDataSource db) =>
{
    try
    {
        await using var conn = await db.OpenConnectionAsync();
        var claims = await GetClaimsAsync(conn, sid);
        if (claims is null) return Results.NotFound();

        return Results.Ok(new
        {
            tenant_id  = claims.Value.tenant_id,
            user_id    = claims.Value.user_id,
            tenant_gln = claims.Value.tenant_gln,
            roles      = claims.Value.roles
        });
    }
    catch (PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex)         { return Results.Problem(ex.Message); }
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
    catch (PostgresException pe) { return PgProblem(pe); }
    catch (Exception ex)         { return Results.Problem(ex.Message); }
});

app.Run();

// ---------- helpers ----------
static async Task<(Guid tenant_id, Guid user_id, string tenant_gln, string[] roles)?> GetClaimsAsync(NpgsqlConnection conn, Guid sid)
{
    await using var cmd = new NpgsqlCommand(
        "SELECT tenant_id, user_id, tenant_gln, roles FROM auth.fn_session_claims(@sid)", conn);
    cmd.Parameters.Add("sid", NpgsqlDbType.Uuid).Value = sid;

    await using var r = await cmd.ExecuteReaderAsync();
    if (!await r.ReadAsync()) return null;

    return (r.GetGuid(0), r.GetGuid(1), r.GetString(2), r.GetFieldValue<string[]>(3));
}

// ---------- JWT issuer ----------
sealed class JwtIssuer
{
    public string Issuer { get; }
    public string Audience { get; }
    public int TtlMinutes { get; }
    public JsonElement Jwk { get; }

    private readonly SigningCredentials _creds;
    private readonly string _kid;

    private JwtIssuer(string issuer, string audience, int ttlMinutes, RSA rsa, string kid, JsonElement jwk)
    {
        Issuer = issuer;
        Audience = audience;
        TtlMinutes = ttlMinutes;
        _kid = kid;
        _creds = new SigningCredentials(new RsaSecurityKey(rsa) { KeyId = kid }, SecurityAlgorithms.RsaSha256);
        Jwk = jwk;
    }

    public static JwtIssuer Create(string issuer, string audience, int ttlMinutes, string? privatePem)
    {
        RSA rsa;
        if (!string.IsNullOrWhiteSpace(privatePem))
        {
            rsa = RSA.Create();
            rsa.ImportFromPem(privatePem);
        }
        else
        {
            // Ephemeral dev key (container restartında değişir)
            rsa = RSA.Create(2048);
            Console.WriteLine("[identity-api] WARNING: Using EPHEMERAL RSA key. Set IDENTITY_JWT_PRIVATE_KEY_PEM for stable keys.");
        }

        // kid üret (base64url(SHA256(modulus||exponent)))
        var parms = rsa.ExportParameters(false);
        var kid = Base64Url(SHA256.HashData(Concat(parms.Modulus!, parms.Exponent!)));

        // JWK (public)
        var jwkObj = new
        {
            kty = "RSA",
            use = "sig",
            alg = "RS256",
            kid,
            n = Base64Url(parms.Modulus!),
            e = Base64Url(parms.Exponent!)
        };
        var jwkJson = JsonSerializer.SerializeToElement(jwkObj);

        return new JwtIssuer(issuer, audience, ttlMinutes, rsa, kid, jwkJson);
    }

    public (string token, int expiresInSeconds) Issue(Guid userId, Guid tenantId, string tenantGln, string[] roles)
    {
        var now = DateTime.UtcNow;
        var exp = now.AddMinutes(TtlMinutes);

        var claims = new List<Claim>
        {
            new("sub", userId.ToString()),
            new("tid", tenantId.ToString()),
            new("gln", tenantGln),
            new("iss", Issuer),
            new("aud", Audience)
        };
        // role claimleri
        foreach (var role in roles) claims.Add(new Claim(ClaimTypes.Role, role));

        var jwt = new JwtSecurityToken(
            issuer: Issuer,
            audience: Audience,
            claims: claims,
            notBefore: now,
            expires: exp,
            signingCredentials: _creds
        );
        var token = new JwtSecurityTokenHandler().WriteToken(jwt);
        return (token, (int)(exp - now).TotalSeconds);
    }

    // utils
    static byte[] Concat(byte[] a, byte[] b)
    {
        var buf = new byte[a.Length + b.Length];
        Buffer.BlockCopy(a, 0, buf, 0, a.Length);
        Buffer.BlockCopy(b, 0, buf, a.Length, b.Length);
        return buf;
    }
    static string Base64Url(byte[] bytes)
        => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
