using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;

namespace Share_Care.Services
{
    public interface ITransactionService
    {
        Task<Transaction> CreateTransactionAsync(Transaction transaction);
        Task<Transaction?> GetTransactionByExternalIdAsync(string externalId);
        Task<Transaction?> GetTransactionByIdAsync(string id);
        Task<List<Transaction>> GetUserTransactionsAsync(string userId);
        Task<Transaction?> MarkAsCompletedAsync(string id);
        Task<Transaction?> MarkAsFailedAsync(string id);
        Task<Transaction?> UpdateTransactionStatusAsync(string id, string status);
    }
}