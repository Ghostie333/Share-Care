using System.ComponentModel.DataAnnotations;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserLoginController : Controller
    {
        private readonly ILogger<UserLoginController> _logger;
        private readonly IMongoCollection<UserData> _users;

        public UserLoginController(ILogger<UserLoginController> logger, IMongoDatabase db)
        {
            _logger = logger;
            _users = db.GetCollection<UserData>("users");
        }

        public sealed class LoginRequest
        {
            [Required, EmailAddress]
            public string Email { get; set; } = string.Empty;

            [Required]
            public string Password { get; set; } = string.Empty;
        }

        // Logowanie WWW (cookie)
        [HttpPost("login-cookie")]
        [Consumes("application/json")]
        public async Task<IActionResult> LoginCookie([FromBody] LoginRequest request, CancellationToken ct)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            // Wyszukanie uzytkownika w bazie danych na podstawie Emaila
            var user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync(ct);
            if (user == null) return Unauthorized("Nieprawidłowy email lub hasło.");

            // TODO: weryfikacja hasła (hash + salt) po dodaniu pola np. PasswordHash w UserData
            // if (!PasswordHasher.Verify(user.PasswordHash, request.Password)) return Unauthorized();

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId ?? String.Empty),
                new Claim(ClaimTypes.Email, user.Email ?? String.Empty),
                new Claim(ClaimTypes.Name, user.Name ?? String.Empty)
            };
            // Utworzenie tożsamości z listą roszczeń (claims)
            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            // Utworzenie principal z tożsamością
            var principal = new ClaimsPrincipal(identity);

            // Zalogowanie użytkownika przy użyciu ciasteczek
            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                principal,
                new AuthenticationProperties
                {
                    IsPersistent = true,
                    ExpiresUtc = DateTimeOffset.UtcNow.AddDays(7) // Czas trwania sesji
                }
            );

            // Zwracamy odpowiedź z danymi użytkownika
            return Ok(new { userId = user.UserId, email = user.Email, name = user.Name, lastName = user.LastName });
        }

        // Logowanie mobilne (JWT)
        [HttpPost("login-jwt")]
        [Consumes("application/json")]
        public async Task<IActionResult> LoginJwt([FromBody] LoginRequest request, CancellationToken ct)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            // Wyszukanie uzytkownika w bazie danych na podstawie Emaila
            var user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync(ct);
            if (user == null) return Unauthorized("Nieprawidłowy email lub hasło.");

            // TODO: weryfikacja hasła (hash + salt) po dodaniu pola np. PasswordHash w UserData
            // if (!PasswordHasher.Verify(user.PasswordHash, request.Password)) return Unauthorized();

            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.UserId ?? String.Empty),
                new Claim(JwtRegisteredClaimNames.Email, user.Email ?? String.Empty),
                new Claim(ClaimTypes.Name, user.Name ?? String.Empty)
            };

            var key = Environment.GetEnvironmentVariable("Auth__Jwt__Key");
            if (string.IsNullOrWhiteSpace(key))
            {
                _logger.LogError("Brak skonfigurowanego Auth__Jwt__Key");
                return StatusCode(StatusCodes.Status500InternalServerError, "Brak konfiguracji JWT");
            }

            var creds = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)), SecurityAlgorithms.HmacSha256);

            var jwt = new JwtSecurityToken(
                claims: claims,
                expires: DateTime.UtcNow.AddHours(1), // Czas trwania sesji
                signingCredentials: creds);

            var token = new JwtSecurityTokenHandler().WriteToken(jwt);

            return Ok(new { access_token = token, token_type = "Bearer", expires_in = 3600 });
        }
    }
}
