using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Services;
using System.ComponentModel.DataAnnotations;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserRegistrationController : Controller
    {
        private readonly IMongoCollection<UserData> _users;
        private readonly ILogger<MainPageController> _logger;
        private readonly SecurityService _security;
        private readonly LoginService _loginService;

        public UserRegistrationController(
            IMongoDatabase db,
            ILogger<MainPageController> logger,
            SecurityService security,
            LoginService loginService)
        {
            _users = db.GetCollection<UserData>("users");
            _logger = logger;
            _security = security;
            _loginService = loginService;
        }

        public sealed class RegistrationRequest
        {
            [Required]
            public string Email { get; set; } = string.Empty;
            [Required]
            public string Password { get; set; } = string.Empty;
            [Required]
            public string FirstName { get; set; } = string.Empty;
            [Required]
            public string LastName { get; set; } = string.Empty;
            [Required]
            public string Birthday { get; set; }
            public string? PhoneNumber { get; set; }
            public string? City { get; set; }
            public string? PostalCode { get; set; }
        }

        // issueJwt=true – zwróci JWT zamiast logowania cookie
        [HttpPost("user-registry")]
        public async Task<IActionResult> UserRegistration([FromBody] RegistrationRequest userRegistration, [FromQuery] bool issueJwt = false)
        {
            try
            {
                var existingUser = await _users
                    .Find(u => u.Email == userRegistration.Email)
                    .FirstOrDefaultAsync();

                if (existingUser != null)
                {
                    return Conflict("User with this email already exists");
                }

                var user = new UserData
                {
                    Email = userRegistration.Email,
                    Password = Convert.ToBase64String(_security.HashPassword(userRegistration.Password)),
                    FirstName = userRegistration.FirstName,
                    LastName = userRegistration.LastName,
                    PhoneNumber = userRegistration.PhoneNumber,
                    Brithday = userRegistration.Birthday,
                    City = userRegistration.City,
                    PostalCode = userRegistration.PostalCode
                };

                await _users.InsertOneAsync(user);

                if (!issueJwt)
                {
                    await _loginService.SignInCookieAsync(HttpContext, user);
                    return Ok(new { userId = user.UserId, email = user.Email, name = user.FirstName, lastName = user.LastName });
                }
                else
                {
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
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during registration");
                return Problem("Couldn't connect to MongoDB", statusCode: StatusCodes.Status500InternalServerError);
            }
        }
    }
}