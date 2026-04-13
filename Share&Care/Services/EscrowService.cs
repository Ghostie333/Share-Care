using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class EscrowService(ILogger<EscrowService> logger, IMongoDatabase db,
                                IWalletService walletSerivce) : IEscrowService
    {
        private readonly ILogger<EscrowService> _logger = logger;
        private readonly IWalletService _walletService = walletSerivce;
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
                await _walletService.UnlockFundsAsync(escrow.BorrowerId, escrow.Amount);
                await _collection.DeleteOneAsync(e => e.Id == escrow.Id);
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
            try
            {
                var escrow = await GetEscrowByOfferIdAsync(offerId);
                await _walletService.UnlockFundsAsync(escrow.LenderId, escrow.Amount);
                await _collection.DeleteOneAsync(e => e.Id == escrow.Id);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się przyjąć depozytu");
                return false;
            }
        }
    }
}