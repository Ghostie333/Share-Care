using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Services;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;

namespace Share_Care.Services
{
    public interface ILoginService
    {
        Task<UserData?> ValidateCredentialsAsync(string email, string password, CancellationToken ct);
        string GenerateJwtToken(UserData user, out DateTime expiresUtc);
    }

    public sealed class LoginService(ILogger<LoginService> logger, IMongoDatabase db, SecurityService security, IConfiguration config) : ILoginService
    {
        private readonly ILogger<LoginService> _logger = logger;
        private readonly IMongoCollection<UserData> _users = db.GetCollection<UserData>("users");
        private readonly SecurityService _security = security;
        private readonly IConfiguration _config = config;

        // Weryfikacja email/has³a, zwraca u¿ytkownika lub null
        public async Task<UserData?> ValidateCredentialsAsync(string email, string password, CancellationToken ct)
        {
            _logger.LogInformation("ValidateCredentials - szukam u¿ytkownika: {Email}", email);

            var cursor = await _users.FindAsync(
                Builders<UserData>.Filter.Eq(u => u.Email, email),
                new FindOptions<UserData, UserData>(),
                ct);
            var hasAny = await cursor.MoveNextAsync(ct);
            var user = hasAny ? cursor.Current.FirstOrDefault() : null;
            if (user == null)
            {
                _logger.LogWarning("ValidateCredentials - nie znaleziono u¿ytkownika: {Email}", email);
                return null;
            }

            _logger.LogInformation("ValidateCredentials - znaleziono u¿ytkownika: {Email}, sprawdzam has³o...", email);
            _logger.LogDebug("ValidateCredentials - stored password hash length: {Length}", user.Password?.Length ?? 0);

            var ok = _security.ComparePasswords(password ?? string.Empty, user.Password ?? string.Empty);

            _logger.LogInformation("ValidateCredentials - wynik porównania has³a: {Result}", ok);

            return ok ? user : null;
        }

        // Generowanie JWT (Flutter Web + Mobile)
        public string GenerateJwtToken(UserData user, out DateTime expiresUtc)
        {
            var claims = new List<Claim>
            {
                new(JwtRegisteredClaimNames.Sub, user.UserId ?? string.Empty),
                new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
                new(ClaimTypes.Name, user.FirstName ?? string.Empty)
            };

            var key = Environment.GetEnvironmentVariable("Auth__Jwt__Key");
            if (string.IsNullOrWhiteSpace(key))
            {
                _logger.LogError("Brak skonfigurowanego Auth__Jwt__Key");
                throw new InvalidOperationException("Brak konfiguracji JWT");
            }

            var creds = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)), SecurityAlgorithms.HmacSha256);

            expiresUtc = DateTime.UtcNow.AddHours(_config.GetValue<int?>("Session:SessionTimeoutHours") ?? 1);

            var jwt = new JwtSecurityToken(
                claims: claims,
                expires: expiresUtc,
                signingCredentials: creds);

            return new JwtSecurityTokenHandler().WriteToken(jwt);
        }
    }
}