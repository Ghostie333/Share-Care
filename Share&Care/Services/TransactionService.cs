using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Services
{
    public class TransactionService(ILogger<TransactionService> logger, IMongoDatabase db) : ITransactionService
    {
        private readonly ILogger<TransactionService> _logger = logger;
        private readonly IMongoCollection<Transaction> _collection =
            db.GetCollection<Transaction>("transactions");

        public async Task<Transaction> CreateTransactionAsync(Transaction transaction)
        {
            transaction.CreatedAt = DateTime.UtcNow;

            if (string.IsNullOrWhiteSpace(transaction.Status))
                transaction.Status = "Pending";

            await _collection.InsertOneAsync(transaction);

            _logger.LogInformation("Transaction created: {Id}", transaction.Id);

            return transaction;
        }

        public async Task<Transaction?> GetTransactionByExternalIdAsync(string externalId)
        {
            if (string.IsNullOrWhiteSpace(externalId))
                return null;

            return await _collection
                .Find(x => x.ExternalId == externalId)
                .FirstOrDefaultAsync();
        }

        public async Task<Transaction?> GetTransactionByIdAsync(string id)
        {
            if (string.IsNullOrWhiteSpace(id))
                return null;

            return await _collection
                .Find(x => x.Id == id)
                .FirstOrDefaultAsync();
        }

        public async Task<List<Transaction>> GetUserTransactionsAsync(string userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return new List<Transaction>();

            return await _collection
                .Find(x => x.UserId == userId)
                .SortByDescending(x => x.CreatedAt)
                .ToListAsync();
        }

        public async Task<Transaction?> MarkAsCompletedAsync(string id)
        {
            return await UpdateStatusInternal(id, "Completed");
        }

        public async Task<Transaction?> MarkAsFailedAsync(string id)
        {
            return await UpdateStatusInternal(id, "Failed");
        }

        public async Task<Transaction?> UpdateTransactionStatusAsync(string id, string status)
        {
            return await UpdateStatusInternal(id, status);
        }

        private async Task<Transaction?> UpdateStatusInternal(string id, string status)
        {
            if (string.IsNullOrWhiteSpace(id))
                return null;

            var update = Builders<Transaction>.Update
                .Set(x => x.Status, status);

            var result = await _collection.FindOneAndUpdateAsync(
                x => x.Id == id,
                update,
                new FindOneAndUpdateOptions<Transaction>
                {
                    ReturnDocument = ReturnDocument.After
                });

            if (result == null)
            {
                _logger.LogWarning("Transaction not found: {Id}", id);
            }
            else
            {
                _logger.LogInformation("Transaction {Id} updated to {Status}", id, status);
            }

            return result;
        }

        public async Task SetExternalIdAsync(string id, string externalId)
        {
            var update = Builders<Transaction>.Update.
                Set(x => x.ExternalId, externalId);

            await _collection.UpdateOneAsync(x => x.Id == id, update);
        }
    }
}