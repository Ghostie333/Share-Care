using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class WalletService(ILogger<WalletService> logger, IMongoDatabase db) : IWalletService
    {
        private readonly ILogger<WalletService> _logger = logger;
        private readonly IMongoCollection<Wallet> _collection = db.GetCollection<Wallet>("wallets");

        public async Task<Wallet?> GetWalletByUserIdAsync(string userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return null;

            var wallet = await _collection.Find(x => x.UserId == userId).FirstOrDefaultAsync();

            return wallet;
        }

        public async Task<decimal> AddFundsAsync(string userId, decimal amount)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return 0;

            var wallet = await _collection.Find(x => x.UserId == userId).FirstOrDefaultAsync();
            var newBalance = wallet.Balance + amount;

            var update = Builders<Wallet>.Update.Set(w => w.Balance, newBalance);

            return newBalance;
        }

        public async Task<bool> LockFundsAsync(string userId, decimal amount)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return false;

            var wallet = await _collection.Find(x => x.UserId == userId).FirstOrDefaultAsync();
            wallet.Balance -= amount;
            wallet.LockedBalance += amount;

            return true;
        }

        public async Task<Wallet?> UnlockFundsAsync(string userId, decimal amount)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return null;

            var wallet = await _collection.Find(x => x.UserId == userId).FirstOrDefaultAsync();
            wallet.Balance += amount;
            wallet.LockedBalance -= amount;

            return wallet;
        }
    }
}