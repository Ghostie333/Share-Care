using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Services;
using Share_Care.Models.Requests;

namespace Share_Care.Services
{
    public interface IWalletService
    {
        Task<Wallet?> CreateUsersWallet(string userId);
        Task<Wallet?> GetWalletByUserIdAsync(string userId);
        Task<Wallet?> GetWalletAsync(string userId); // Alias for GetWalletByUserIdAsync
        Task<decimal> AddFundsAsync(string userId, decimal amount);
        Task<bool> LockFundsAsync(string userId, decimal amount);
        Task<Wallet?> UnlockFundsAsync(string userId, decimal amount);
        Task<bool> TransferLockedFundsAsync(string fromUserId, string toUserId, decimal amount);
        Task<decimal?> WithdrawFundsAsync(string userId, decimal amount);
        Task<bool> DeductAsync(string userId, decimal amount);
    }
}