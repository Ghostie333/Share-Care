using Microsoft.AspNetCore.Mvc;
using Share_Care.Services;
using Share_Care.Models.Requests;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserLoginController(ILogger<UserLoginController> logger, ILoginService loginService) : ControllerBase
    {
        private readonly ILogger<UserLoginController> _logger = logger;
        private readonly ILoginService _loginService = loginService;

        // Logowanie (JWT)
        [HttpPost("login")]
        [Consumes("application/json")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request, CancellationToken ct)
        {
            if (!ModelState.IsValid)
            {
                _logger.LogWarning("Login attempt with invalid model state from IP: {IP}", HttpContext.Connection.RemoteIpAddress);
                return BadRequest(ModelState);
            }

            var user = await _loginService.ValidateCredentialsAsync(request.Email, request.Password, ct);
            if (user is null)
            {
                _logger.LogWarning("Failed login attempt for email: {Email} from IP: {IP}", 
                    request.Email, HttpContext.Connection.RemoteIpAddress);
                return Unauthorized(new { error = "Nieprawidłowy email lub hasło" });
            }

            try
            {
                var token = _loginService.GenerateJwtToken(user, out var expiresUtc);
                _logger.LogInformation("Successful login for user: {UserId} ({Email})", user.UserId, user.Email);
                return Ok(new { access_token = token, token_type = "Bearer", expires_in = expiresUtc });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogError(ex, "JWT configuration error during login for user: {Email}", request.Email);
                return StatusCode(StatusCodes.Status500InternalServerError, new { error = "Brak konfiguracji JWT" });
            }
        }
    }
}
