using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Share_Care.Services;
using System.Security.Claims;

namespace Share_Care.Controllers
{
    [ApiController]
    [Route("wallet")]
    public class WalletController(IWalletService walletService) : ControllerBase
    {
        private readonly IWalletService _walletService = walletService;

        [Authorize]
        [HttpGet("me")]
        public async Task<IActionResult> GetMyWallet()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var wallet = await _walletService.GetWalletByUserIdAsync(userId)
                ?? await _walletService.CreateUsersWallet(userId);

            if (wallet == null)
                return NotFound();

            return Ok(new
            {
                balance = wallet.Balance,
                lockedBalance = wallet.LockedBalance,
                availableBalance = wallet.GetAvailableBalance()
            });
        }

        [Authorize]
        [HttpPost("withdraw")]
        public async Task<IActionResult> Withdraw([FromQuery] decimal amount)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            if (amount <= 0)
                return BadRequest("Amount must be greater than 0");

            var newBalance = await _walletService.WithdrawFundsAsync(userId, amount);
            if (newBalance == null)
                return BadRequest("Insufficient funds");

            return Ok(new { balance = newBalance });
        }
    }
}
