using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class TransactionService(ILogger<TransactionService> logger, IMongoDatabase db) : ITransactionService
    {
        private readonly ILogger<TransactionService> _logger = logger;
        private readonly IMongoCollection<Transaction> _collection = db.GetCollection<Transaction>("transactions");

        public Task<Transaction> CreateTransactionAsync()
        {
            throw new NotImplementedException();
        }

        public Task<Transaction> GetTransactionByExternalIdAsync()
        {
            throw new NotImplementedException();
        }

        public Task<Transaction> GetTransactionByIdAsync()
        {
            throw new NotImplementedException();
        }

        public Task<List<Transaction>> GetUserTransactionsAsync()
        {
            throw new NotImplementedException();
        }

        public Task<Transaction> MarkAsCompletedAsync()
        {
            throw new NotImplementedException();
        }

        public Task<Transaction> MarkAsFailedAsync()
        {
            throw new NotImplementedException();
        }

        public Task<Transaction> UpdateTransactionStatusAsync()
        {
            throw new NotImplementedException();
        }
    }
}