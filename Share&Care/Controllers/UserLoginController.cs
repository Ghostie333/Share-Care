using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using System.ComponentModel.DataAnnotations;

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
    }
}
