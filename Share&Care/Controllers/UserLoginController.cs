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
        private readonly LoginService _loginService;

        public UserLoginController(ILogger<UserLoginController> logger, LoginService loginService)
        {
            _logger = logger;
            _loginService = loginService;
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

            var user = await _loginService.ValidateCredentialsAsync(request.Email, request.Password, ct);
            if (user is null) return Unauthorized("Nieprawidłowy email lub hasło");

            await _loginService.SignInCookieAsync(HttpContext, user);

            // Zwracamy odpowiedź z danymi użytkownika
            return Ok(new { userId = user.UserId, email = user.Email, name = user.FirstName, lastName = user.LastName });
        }


        // Logowanie mobilne (JWT)
        [HttpPost("login-jwt")]
        [Consumes("application/json")]
        public async Task<IActionResult> LoginJwt([FromBody] LoginRequest request, CancellationToken ct)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _loginService.ValidateCredentialsAsync(request.Email, request.Password, ct);
            if (user is null) return Unauthorized("Nieprawidłowy email lub hasło");

            try
            {
                var token = _loginService.GenerateJwtToken(user, out var expiresUtc);
                return Ok(new { access_token = token, token_type = "Bearer", expires_in = expiresUtc });
            }
            catch (InvalidOperationException)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, "Brak konfiguracji JWT");
            }
        }
    }
}
