using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Services;
using System.ComponentModel.DataAnnotations;
using System.Runtime.InteropServices;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserRegistrationController : Controller
    {
        private readonly IMongoCollection<UserData> _users;
        private readonly ILogger<MainPageController> _logger;
        private readonly SecurityService _security;

        public UserRegistrationController(IMongoDatabase db, 
                                          ILogger<MainPageController> logger,
                                          SecurityService security)
        {
            _users = db.GetCollection<UserData>("users");
            _logger = logger;
            _security = security;
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
            public string? PhoneNumber { get; set; }
            [Required]
            public string Birthday { get; set; }
            public string? City { get; set; }
            public string? PostalCode { get; set; }
        }

        [HttpPost("user-registry")]
        public async Task<IActionResult> UserRegistration([FromBody] RegistrationRequest userRegistration)
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

                UserData user = new UserData();
                user.Email = userRegistration.Email;
                user.Password = Convert.ToBase64String(_security.HashPassword(userRegistration.Password));
                user.FirstName = userRegistration.FirstName;
                user.LastName = userRegistration.LastName;
                user.PhoneNumber = userRegistration.PhoneNumber;
                user.Brithday = userRegistration.Birthday;
                user.City = userRegistration.City;
                user.PostalCode = userRegistration.PostalCode;

                await _users.InsertOneAsync(user);

                return Ok("Registration completed");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during registration");
                return Problem("Couldn't connect to MongoDB", statusCode: StatusCodes.Status500InternalServerError);
            }
        }
    }
}