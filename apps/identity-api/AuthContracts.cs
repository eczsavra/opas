namespace AuthContracts
{
    public record LoginReq(string gln, string email, string password);
    public record RefreshReq(string refresh_token);
    public record LogoutReq(System.Guid sid);

    public record LoginResponse(System.Guid session_id, string refresh_token, string access_token, int expires_in);
    public record RefreshResponse(System.Guid session_id, string refresh_token, string access_token, int expires_in);
}
