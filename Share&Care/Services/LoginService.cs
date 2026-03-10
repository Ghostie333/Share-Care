using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Services;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Share_Care.Services
{
    public sealed class LoginService(ILogger<LoginService> logger, IMongoDatabase db, SecurityService security, IConfiguration config)
    {
        private readonly ILogger<LoginService> _logger = logger;
        private readonly IMongoCollection<UserData> _users = db.GetCollection<UserData>("users");
        private readonly SecurityService _security = security;
        private readonly IConfiguration _config = config;

        // Weryfikacja email/has³a, zwraca u¿ytkownika lub null
        public async Task<UserData?> ValidateCredentialsAsync(string email, string password, CancellationToken ct)
        {
            var user = await _users.Find(u => u.Email == email).FirstOrDefaultAsync(ct);
            if (user == null) return null;

            var ok = _security.ComparePasswords(password ?? string.Empty, user.Password ?? string.Empty);
            return ok ? user : null;
        }

        // Logowanie przez ciasteczka (WWW)
        public async Task SignInCookieAsync(HttpContext httpContext, UserData user)
        {
            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.UserId ?? string.Empty),
                new(ClaimTypes.Email, user.Email ?? string.Empty),
                new(ClaimTypes.Name, user.FirstName ?? string.Empty)
            };

            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            var principal = new ClaimsPrincipal(identity);

            await httpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                principal,
                new AuthenticationProperties
                {
                    IsPersistent = true,
                    ExpiresUtc = DateTime.UtcNow.AddHours(_config.GetValue<int?>("Session:SessionTimeoutHours") ?? 1)
                });
        }

        // Generowanie JWT (mobilne)
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