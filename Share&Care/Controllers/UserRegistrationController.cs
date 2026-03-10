using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Services;
using Share_Care.Models.Requests;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserRegistrationController(IMongoDatabase db, ILogger<UserRegistrationController> logger,
                                           SecurityService security, LoginService loginService) : ControllerBase
    {
        private readonly IMongoCollection<UserData> _users = db.GetCollection<UserData>("users");
        private readonly ILogger<UserRegistrationController> _logger = logger;
        private readonly SecurityService _security = security;
        private readonly LoginService _loginService = loginService;

        [HttpPost("user-registry")]
        public async Task<IActionResult> UserRegistration([FromBody] RegistrationRequest userRegistration)
        {
            _logger.LogInformation("Rozpoczêto rejestracjê u¿ytkownika, email: {Email}", userRegistration.Email);

            try
            {
                var existingUser = await _users
                    .Find(u => u.Email == userRegistration.Email)
                    .FirstOrDefaultAsync();

                if (existingUser != null)
                {
                    _logger.LogWarning("Próba rejestracji z istniej¹cym emailem: {Email}", userRegistration.Email);
                    return Conflict(new { error = "User with this email already exists" });
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
                _logger.LogInformation("Pomyœlnie utworzono u¿ytkownika {UserId}, email: {Email}", 
                    user.UserId, user.Email);

                try
                {
                    var token = _loginService.GenerateJwtToken(user, out var expiresUtc);
                    _logger.LogInformation("Wygenerowano JWT token dla u¿ytkownika {UserId}", user.UserId);
                    return Ok(new { access_token = token, token_type = "Bearer", expires_in = expiresUtc });
                }
                catch (InvalidOperationException ex)
                {
                    _logger.LogError(ex, "Brak konfiguracji JWT dla u¿ytkownika {UserId}", user.UserId);
                    return StatusCode(StatusCodes.Status500InternalServerError, new { error = "Brak konfiguracji JWT" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "B³¹d podczas rejestracji u¿ytkownika, email: {Email}", userRegistration.Email);
                return Problem("Couldn't connect to MongoDB", statusCode: StatusCodes.Status500InternalServerError);
            }
        }
    }
}