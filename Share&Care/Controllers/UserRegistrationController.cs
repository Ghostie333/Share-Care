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
        private readonly SecurityService _security;

        public UserRegistrationController(IMongoDatabase db, SecurityService security)
        {
            _users = db.GetCollection<UserData>("users");
            _security = security;
        }

        public sealed class RegistrationRequest
        {
            [Required]
            public string Email { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
            public string FirstName { get; set; } = string.Empty;
            public string LastName { get; set; } = string.Empty;
        }

        [HttpPost("user-registry")]
        public async Task<IActionResult> UserRegistration([FromBody] RegistrationRequest userRegistration)
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

            await _users.InsertOneAsync(user);

            return Ok("Registration completed");
        }
    }
}