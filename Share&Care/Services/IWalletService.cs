using Share_Care.models;
using Microsoft.AspNetCore.Http;

namespace Share_Care.Services
{
    public interface IWalletService
    {
        Task<Wallet?> GetWalletByUserIdAsync(string userId);
        Task<decimal> AddFundsAsync(string userId, decimal amount);
        Task<bool> LockFundsAsync(string userId, decimal amount);
        Task<Wallet?> UnlockFundsAsync(string userId, decimal amount);
    }
}