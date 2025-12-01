using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UserRegistrationController : Controller
    {
        private readonly IMongoCollection<UserData> _users;

        public UserRegistrationController(IMongoDatabase db)
        {
            _users = db.GetCollection<UserData>("users");
        }

        [HttpPost("user-registry")]
        public async Task<IActionResult> UserRegistration([FromBody] UserData userData)
        {
            var email = await _users.FindAsync<string>(userData.Email);

            if (email != null)
            {
                return View("User with that email already exists");
            }

            return Ok("Registration completed");
        }
    }
}