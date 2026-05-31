using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Services
{
    public class RewardsService(IMongoDatabase db, IWalletService walletService, ILogger<RewardsService> logger) : IRewardsService
    {
        private readonly IMongoCollection<UserData> _users = db.GetCollection<UserData>("users");
        private readonly IWalletService _walletService = walletService;
        private readonly ILogger<RewardsService> _logger = logger;

        private const decimal PER_PLN_RATE = 4m;

        public async Task<bool> AwardCreditsAsync(string userId, int credits)
        {
            if (string.IsNullOrWhiteSpace(userId) || credits <= 0)
                return false;

            try
            {
                var update = Builders<UserData>.Update.Inc(u => u.Credits, credits);
                var result = await _users.UpdateOneAsync(u => u.UserId == userId, update);

                _logger.LogInformation("Awarded {Credits} credits to user {UserId}", credits, userId);
                return result.ModifiedCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to award credits to user {UserId}", userId);
                return false;
            }
        }

        public async Task<bool> AwardGiverBonusAsync(string giverId, decimal bonusAmount)
        {
            if (string.IsNullOrWhiteSpace(giverId) || bonusAmount <= 0)
                return false;

            // Convert bonus amount to credits (1 PLN = 4 credits)
            var credits = (int)(bonusAmount * PER_PLN_RATE);

            try
            {
                var update = Builders<UserData>.Update.Inc(u => u.Credits, credits);
                var result = await _users.UpdateOneAsync(u => u.UserId == giverId, update);

                _logger.LogInformation("Awarded {Credits} credits to giver {GiverId} from {BonusAmount} PLN bonus", credits, giverId, bonusAmount);
                return result.ModifiedCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to award bonus credits to giver {GiverId}", giverId);
                return false;
            }
        }

        public async Task<bool> ConvertWalletToCreditsAsync(string userId, decimal amount)
        {
            if (string.IsNullOrWhiteSpace(userId) || amount <= 0)
                return false;

            var wallet = await _walletService.GetWalletAsync(userId);
            if (wallet == null || !wallet.HasSufficientFunds(amount))
                return false;

            // Deduct from wallet
            var deducted = await _walletService.DeductAsync(userId, amount);
            if (!deducted)
                return false;

            // Calculate credits (1 PLN = 4 credits)
            var credits = (int)(amount * PER_PLN_RATE);

            // Add credits to user
            var update = Builders<UserData>.Update.Inc(u => u.Credits, credits);
            var result = await _users.UpdateOneAsync(u => u.UserId == userId, update);

            _logger.LogInformation("User {UserId} converted {Amount} PLN to {Credits} credits", userId, amount, credits);
            return result.ModifiedCount > 0;
        }
    }
}
