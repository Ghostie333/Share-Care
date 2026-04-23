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
        Task<decimal> AddFundsAsync(string userId, decimal amount);
        Task<bool> LockFundsAsync(string userId, decimal amount);
        Task<Wallet?> UnlockFundsAsync(string userId, decimal amount);
    }
}