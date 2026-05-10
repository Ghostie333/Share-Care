using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;
using Share_Care.Services;
using System.Security.Claims;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("rewards")]
    public class RewardsController(IMongoDatabase db, IRewardsService rewardsService, ILogger<RewardsController> logger) : ControllerBase
    {
        private readonly IMongoCollection<UserData> _users = db.GetCollection<UserData>("users");
        private readonly IRewardsService _rewardsService = rewardsService;
        private readonly ILogger<RewardsController> _logger = logger;

        // 1 PLN = 4 ShareCoins
        private const decimal PER_PLN_RATE = 4m;

        private static readonly List<(string id, string name, string description, int cost)> _rewards =
        [
            ("reward-1000", "Voucher 50 PLN", "Voucher do popularnego sklepu", 1000),
            ("reward-2500", "Voucher 150 PLN", "Wyższa wartość na zakupy", 2500),
            ("reward-5000", "Paczka premium", "Specjalny zestaw nagród", 5000)
        ];

        [HttpGet("list")]
        public IActionResult List()
        {
            return Ok(_rewards.Select(r => new
            {
                id = r.id,
                name = r.name,
                description = r.description,
                cost = r.cost
            }));
        }

        [Authorize]
        [HttpPost("redeem")]
        public async Task<IActionResult> Redeem([FromBody] RedeemRewardRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var reward = _rewards.FirstOrDefault(r => r.id == request.RewardId);
            if (reward.id == null)
                return NotFound("Reward not found");

            var user = await _users.Find(u => u.UserId == userId).FirstOrDefaultAsync();
            if (user == null)
                return NotFound("User not found");

            if (user.Credits < reward.cost)
                return BadRequest("Not enough credits");

            var update = Builders<UserData>.Update.Inc(u => u.Credits, -reward.cost);
            await _users.UpdateOneAsync(u => u.UserId == userId, update);

            return Ok(new { credits = user.Credits - reward.cost });
        }

        [Authorize]
        [HttpPost("convert-to-credits")]
        public async Task<IActionResult> ConvertWalletToCredits([FromQuery] decimal amount)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            if (amount <= 0)
                return BadRequest("Amount must be greater than 0");

            var ok = await _rewardsService.ConvertWalletToCreditsAsync(userId, amount);
            if (!ok)
                return BadRequest("Conversion failed - insufficient funds or user not found");

            var user = await _users.Find(u => u.UserId == userId).FirstOrDefaultAsync();
            return Ok(new { credits = user?.Credits ?? 0, creditsAdded = (int)(amount * PER_PLN_RATE) });
        }

        [Authorize]
        [HttpGet("balance")]
        public async Task<IActionResult> GetBalance()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var user = await _users.Find(u => u.UserId == userId).FirstOrDefaultAsync();
            if (user == null)
                return NotFound("User not found");

            return Ok(new
            {
                credits = user.Credits
            });
        }

        public async Task<bool> AwardGiverBonusAsync(string giverId, decimal bonusAmount)
        {
            return await _rewardsService.AwardGiverBonusAsync(giverId, bonusAmount);
        }
    }
}
