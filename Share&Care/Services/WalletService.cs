using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class WalletService(ILogger<WalletService> logger, IMongoDatabase db) : IWalletService
    {
        private readonly ILogger<WalletService> _logger = logger;
        private readonly IMongoCollection<Wallet> _collection = db.GetCollection<Wallet>("wallets");

        public async Task<Wallet?> CreateUsersWallet(string userId)
        {
            var user = await db.GetCollection<UserData>("users")
                        .Find(u => u.UserId == userId).FirstOrDefaultAsync();
            
            if (user == null)
            {
                _logger.LogError("Użytkownik o tym ID nie istnieje");
                return null;
            }
            
            var walletCheck = await _collection.Find(w => w.UserId == userId).FirstOrDefaultAsync();

            if (walletCheck != null)
            {
                _logger.LogError("Portfel dla tego użytkownika już istnieje");
                return null;
            }

            var wallet = new Wallet { UserId = userId };

            await _collection.InsertOneAsync(wallet);

            return wallet;
        }

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

            var wallet = await GetWalletByUserIdAsync(userId);

            if (wallet == null)
                return 0;

            var newBalance = wallet.Balance + amount;

            await _collection.UpdateOneAsync(
                x => x.UserId == userId,
                Builders<Wallet>.Update
                    .Inc(w => w.Balance, amount)
             );

            return newBalance;
        }

        public async Task<bool> LockFundsAsync(string userId, decimal amount)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return false;

            var wallet = await GetWalletByUserIdAsync(userId);

            if(wallet == null)
                return false;

            if (!wallet.HasSufficientFunds(amount))
                return false;

            await _collection.UpdateOneAsync(
                x => x.UserId == userId,
                Builders<Wallet>.Update
                    .Inc(w => w.Balance, -amount)
                    .Inc(w => w.LockedBalance, +amount)
             );

            return true;
        }

        public async Task<Wallet?> UnlockFundsAsync(string userId, decimal amount)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return null;

            await _collection.UpdateOneAsync(
                x => x.UserId == userId,
                Builders<Wallet>.Update
                    .Inc(w => w.Balance, amount)
                    .Inc(w => w.LockedBalance, -amount)
             );

            var wallet = await GetWalletByUserIdAsync(userId);

            return wallet;
        }
    }
}