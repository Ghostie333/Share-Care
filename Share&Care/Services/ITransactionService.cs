using MongoDB.Driver;
using Share_Care.models;
using Share_Care.Models.Requests;

namespace Share_Care.Services
{
    public interface ITransactionService
    {
        Task<Transaction> CreateTransactionAsync();
        Task<Transaction> GetTransactionByIdAsync();
        Task<Transaction> GetTransactionByExternalIdAsync();
        Task<Transaction> UpdateTransactionStatusAsync();
        Task<Transaction> MarkAsCompletedAsync();
        Task<Transaction> MarkAsFailedAsync();
        Task<List<Transaction>> GetUserTransactionsAsync();
    }
}