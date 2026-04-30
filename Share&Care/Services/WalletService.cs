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
            var wallet = new Wallet { UserId = userId };

            // DODAC SPRAWDZANIE CZY PORTFEL JUZ ISTNIEJE

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
            var result = await _collection.UpdateOneAsync(
                x => x.UserId == userId && x.Balance >= amount,
                Builders<Wallet>.Update
                .Inc(w => w.Balance, -amount)
                .Inc(w => w.LockedBalance, amount)
            );

            return result.ModifiedCount > 0;
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