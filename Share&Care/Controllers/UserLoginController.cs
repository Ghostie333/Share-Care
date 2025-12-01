using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using MongoDB.Driver.Linq;
using Share_Care.models;
using Share_Care.Services;
using System.ComponentModel.DataAnnotations;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserLoginController : Controller
    {
        private readonly ILogger<UserLoginController> _logger;
        private readonly IMongoCollection<UserData> _users;
        private readonly SecurityService _security;
        private readonly IConfiguration _config;

        public UserLoginController(ILogger<UserLoginController> logger, IMongoDatabase db, SecurityService security, IConfiguration config)
        {
            _logger = logger;
            _users = db.GetCollection<UserData>("users");
            _security = security;
            _config = config;
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

            var userResult = await CheckLoginRequest(request, ct);
            if (userResult.Result is IActionResult error) return error; // Unauthorized/BadRequest

            var user = userResult.Value!;
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId ?? String.Empty),
                new Claim(ClaimTypes.Email, user.Email ?? String.Empty),
                new Claim(ClaimTypes.Name, user.FirstName ?? String.Empty)
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
                    ExpiresUtc = DateTime.UtcNow.AddHours(_config.GetValue<int?>("Session:SessionTimeoutHours") ?? 1) // Czas trwania sesji
                }
            );

            // Zwracamy odpowiedź z danymi użytkownika
            return Ok(new { userId = user.UserId, email = user.Email, name = user.FirstName, lastName = user.LastName });
        }


        // Logowanie mobilne (JWT)
        [HttpPost("login-jwt")]
        [Consumes("application/json")]
        public async Task<IActionResult> LoginJwt([FromBody] LoginRequest request, CancellationToken ct)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var userResult = await CheckLoginRequest(request, ct);
            if (userResult.Result is IActionResult error) return error; // Unauthorized/BadRequest

            var user = userResult.Value!;
            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.UserId ?? String.Empty),
                new Claim(JwtRegisteredClaimNames.Email, user.Email ?? String.Empty),
                new Claim(ClaimTypes.Name, user.FirstName ?? String.Empty)
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
                expires: DateTime.UtcNow.AddHours(_config.GetValue<int?>("Session:SessionTimeoutHours") ?? 1), // Czas trwania sesji
                signingCredentials: creds);

            var token = new JwtSecurityTokenHandler().WriteToken(jwt);

            return Ok(new { access_token = token, token_type = "Bearer", expires_in = jwt.ValidTo });
        }

        // Sprawdzenie czy użytkownik istnieje i czy hasło jest poprawne
        private async Task<ActionResult<UserData>> CheckLoginRequest(LoginRequest request, CancellationToken ct)
        {
            var user = await _users.Find(u => u.Email == request.Email).FirstOrDefaultAsync(ct);
            if (user == null) return Unauthorized("Nieprawidłowy email lub hasło");

            if (!_security.ComparePasswords(request.Password ?? string.Empty, user.Password ?? string.Empty))
                return Unauthorized("Nieprawidłowy email lub hasło");

            return user;
        }
    }
}
