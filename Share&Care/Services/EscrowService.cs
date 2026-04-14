using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class EscrowService(ILogger<EscrowService> logger, IMongoDatabase db,
                                IWalletService walletSerivce, IMongoClient client) : IEscrowService
    {
        private readonly ILogger<EscrowService> _logger = logger;
        private readonly IWalletService _walletService = walletSerivce;
        private readonly IMongoClient _client = client;
        private readonly IMongoCollection<Wallet> _walletCollection = db.GetCollection<Wallet>("wallets");
        private readonly IMongoCollection<Escrow> _collection = db.GetCollection<Escrow>("escrows");

        public async Task<Escrow> CreateEscrowAsync(string borrowerId, string lenderId, 
            string offerId, decimal amount)
        {
            var escrow = new Escrow
            {
                BorrowerId = borrowerId,
                LenderId = lenderId,
                OfferId = offerId,
                Amount = amount,
                Status = "locked"
            };

            try
            {
                await _walletService.LockFundsAsync(borrowerId, amount);
                await _collection.InsertOneAsync(escrow);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się utworzyć depozytu");
                return null;
            }

            return escrow;
        }

        public async Task<Escrow> GetEscrowByOfferIdAsync(string offerId)
        {
            try
            {
                var escrow = await _collection.Find(e => e.OfferId == offerId).FirstOrDefaultAsync();
                return escrow;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się pobrać depozytu");
                return null;
            }
        }

        public async Task<Escrow> GetEscrowByUserIdAsync(string userId)
        {
            try
            {
                var escrow = await _collection.Find(e => e.BorrowerId == userId || e.LenderId == userId)
                    .FirstOrDefaultAsync();
                return escrow;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się pobrać depozytu");
                return null;
            }
        }

        public async Task<bool> ReleaseEscrowAsync(string offerId)
        {
            try
            {
                var escrow = await GetEscrowByOfferIdAsync(offerId);

                if (escrow == null)
                    return false;

                if (escrow.Status != "locked")
                    return false;

                await _walletService.UnlockFundsAsync(escrow.BorrowerId, escrow.Amount);
                await _collection.UpdateOneAsync(
                        x => x.Id == escrow.Id,
                        Builders<Escrow>.Update
                        .Set(x => x.Status, "Released")
                    );

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się zwolnić depozytu");
                return false;
            }
        }

        public async Task<bool> ClaimEscrowAsync(string offerId)
        {
            using var session = await _client.StartSessionAsync();

            session.StartTransaction();

            try
            {
                var escrow = await _collection
                    .Find(session, e => e.OfferId == offerId)
                    .FirstOrDefaultAsync();

                if (escrow == null || escrow.Status != "locked")
                {
                    await session.AbortTransactionAsync();
                    return false;
                }

                // 1. Remove locked funds from borrower
                await _walletCollection.UpdateOneAsync(
                    session,
                    x => x.UserId == escrow.BorrowerId,
                    Builders<Wallet>.Update
                        .Inc(w => w.LockedBalance, -escrow.Amount)
                );

                // 2. Add funds to lender
                await _walletCollection.UpdateOneAsync(
                    session,
                    x => x.UserId == escrow.LenderId,
                    Builders<Wallet>.Update
                        .Inc(w => w.Balance, escrow.Amount)
                );

                // 3. Update escrow status
                await _collection.UpdateOneAsync(
                    session,
                    x => x.Id == escrow.Id,
                    Builders<Escrow>.Update
                        .Set(x => x.Status, "Claimed")
                );

                await session.CommitTransactionAsync();
                return true;
            }
            catch (Exception ex)
            {
                await session.AbortTransactionAsync();
                _logger.LogError(ex, "Transakcja nieudana");
                return false;
            }
        }
    }
}