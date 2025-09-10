using Prometheus;

namespace Identity.Api;

public static class AppMetrics
{
    public static readonly Counter LoginTotal   = Metrics.CreateCounter("opas_identity_login_total",   "Toplam login denemeleri");
    public static readonly Counter RefreshTotal = Metrics.CreateCounter("opas_identity_refresh_total", "Toplam refresh denemeleri");
    public static readonly Counter LogoutTotal  = Metrics.CreateCounter("opas_identity_logout_total",  "Toplam logout denemeleri");

    // Kullanan kodu kırmamak için pass-through
    public static T WithRequest<T>(T handler) where T : Delegate => handler;
}
