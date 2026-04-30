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
            var exisitingWallet = await _collection.FindAsync(w => w.UserId == userId);

            if (exisitingWallet != null)
                return null;

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

        public async Task<bool> TransferLockedFundsAsync(string fromUserId, string toUserId, decimal amount)
        {
            // 1. Zmniejszenie zablokowanych funduszy sendera
            var deduct = await _collection.UpdateOneAsync(
                x => x.UserId == fromUserId && x.LockedBalance >= amount,
                Builders<Wallet>.Update
                    .Inc(w => w.LockedBalance, -amount)
            );

            if (deduct.ModifiedCount == 0)
                return false;

            // 2. Zwieksz balans receivera
            await _collection.UpdateOneAsync(
                x => x.UserId == toUserId,
                Builders<Wallet>.Update
                    .Inc(w => w.Balance, amount)
            );

            return true;
        }
    }
}