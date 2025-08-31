namespace AuthContracts
{
    public record LoginReq(string gln, string email, string password);
    public record RefreshReq(string refresh_token);
    public record LogoutReq(System.Guid sid);
}
